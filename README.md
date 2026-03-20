# dabom-infra-platform

DABOM 프로젝트의 애플리케이션 플랫폼 레이어. ECS Fargate 서비스, ALB, Amazon MSK(Kafka), ElastiCache(Redis), RDS(MySQL), SSM Parameter Store, ACM 인증서, Cloudflare DNS를 관리하는 Terraform 인프라 코드입니다.

## 개요

이 레이어는 bootstrap 레이어에서 생성된 기반 인프라(VPC, 보안그룹, IAM, ECR)를 바탕으로 애플리케이션 실행 환경을 구성합니다. 모든 주요 인프라 리소스는 AWS로 관리되며, DNS는 Cloudflare와 통합됩니다.

## 아키텍처

```
Internet
   |
   +---> Cloudflare DNS (api.dabom.site, noti.dabom.site, batch.dabom.site)
          |
          +---> ACM *.dabom.site (HTTPS)
                 |
                 +---> ALB API (idle_timeout 60초)
                 |      |
                 |      +---> api-core (ECS Service, 1 replica)
                 |      +---> batch-core (ECS Service, 1 replica, host-based rule)
                 |
                 +---> ALB Noti (idle_timeout 300초, SSE)
                        |
                        +---> api-notification (ECS Service, 1 replica)

ECS Cluster (dabom-ecs-cluster)
   |
   +---> processor-usage (ECS Service, 2 replicas, Kafka consumer)

Data Layer (Public Subnet)
   +---> RDS MySQL 8.0 (db.t3.small, 20GB gp3)
   +---> ElastiCache Redis 7 (cache.t3.medium, 단일 노드)
   +---> MSK Kafka 3.6.0 (t3.small x2 브로커, 10GB EBS)

Service Discovery
   +---> Cloud Map Namespace (dabom.local)
        +---> api-core
        +---> processor-usage
        +---> api-notification
        +---> batch-core

SSM Parameter Store
   +---> 7개 SecureString (DB, JWT, R2, VAPID, Slack)
   +---> 23개+ String (URL, 설정값)
```

## 모듈 구성

### modules/ecs-cluster

ECS 클러스터를 관리합니다.

- **클러스터명**: dabom-ecs-cluster
- **런치 타입**: Fargate + Fargate Spot capacity provider
- **Container Insights**: 비활성화(비용 절감)
- **용량 전략**: FARGATE를 기본 공급자로 사용

### modules/ecs-service

ECS 서비스 및 작업 정의를 관리하는 재사용 모듈입니다. 4개 서비스에서 호출됩니다.

**주요 설정:**

- 네트워크 모드: awsvpc (Fargate 전용)
- 런치 타입: Fargate
- ECS Exec 활성화: `enable_execute_command = true` (SSH 없이 컨테이너 접근 가능)
- 헬스 체크 유예 기간: ALB 연결 시 180초
- 로깅: CloudWatch Logs (awslogs, 1일 보관)
- 애플리케이션 로그: OTLP로 별도 전송

**수명 주기 관리:**

```hcl
lifecycle {
  ignore_changes = [desired_count]  # 오토스케일링이 조정한 값을 Terraform이 되돌리지 않음
}
```

**4개 서비스 구성:**

| 서비스 | CPU | Memory | 레플리카 | ALB | 설명 |
|--------|-----|--------|---------|-----|------|
| api-core | 1024 | 2048 | 1 | alb-api (default) | REST API, R2 업로드 처리 |
| processor-usage | 512 | 1024 | 2 | 없음 | Kafka 소비자, 사용량 처리 |
| api-notification | 1024 | 2048 | 1 | alb-noti | SSE 기반 알림 서비스, VAPID Web Push |
| batch-core | 1024 | 2048 | 1 | alb-api (host-based) | Spring Batch + @Scheduled 스케줄러 |

### 환경변수 및 시크릿 관리

모든 환경변수와 시크릿은 SSM Parameter Store에서 중앙 관리되며, ECS Task Definition의 `valueFrom` 필드를 통해 주입됩니다.

**공통 값 (모든 서비스):**

```hcl
locals {
  common_secrets = [
    DATABASE_URL,
    DATABASE_USER,
    DATABASE_PASSWORD,
    REDIS_HOST,
    REDIS_PORT,
    OTEL_SDK_DISABLED,
    OTEL_EXPORTER_OTLP_ENDPOINT
  ]
}
```

**Kafka 사용 서비스 (api-core, processor-usage, api-notification):**

```hcl
locals {
  kafka_common_secrets = [
    KAFKA_BOOTSTRAP_SERVERS,
    KAFKA_AUTO_OFFSET_RESET,
    KAFKA_POLICY_DEDUP_TTL_SECONDS,
    KAFKA_USAGE_PERSIST_DEDUP_TTL_SECONDS
  ]
}
```

**JWT 사용 서비스 (api-core, api-notification):**

```hcl
locals {
  jwt_secrets = [
    JWT_SECRET_KEY,
    JWT_ACCESS_TOKEN_EXPIRES_IN,
    JWT_REFRESH_TOKEN_EXPIRES_IN
  ]
}
```

**CORS 사용 서비스 (api-core, processor-usage, api-notification):**

```hcl
locals {
  cors_secrets = [
    FRONTEND_URL
  ]
}
```

**서비스별 고유값:**

- **api-core**: R2 엔드포인트, 액세스 키, 시크릿 키, 버킷명, CDN URL
- **processor-usage**: 추가 없음
- **api-notification**: VAPID 공개/비밀 키
- **batch-core**: Slack Webhook URL, 스케줄 활성화/Cron 표현식, 배치 튜닝 파라미터

### modules/alb

응용 프로그램 로드 밸런서 2개를 관리합니다.

**alb-api (api-core, batch-core 호스팅):**

- idle_timeout: 60초 (일반 REST API)
- 포트: 80 (HTTP), 443 (HTTPS)
- 타겟 그룹 1: api-core (기본 동작)
- 타겟 그룹 2: batch-core (호스트 기반 라우팅, batch.dabom.site)
- 헬스 체크 경로: /actuator/health
- HTTPS 리스너: ACM *.dabom.site 인증서 적용

**alb-noti (api-notification 호스팅):**

- idle_timeout: 300초 (SSE 장기 연결 지원)
- 포트: 80 (HTTP), 443 (HTTPS)
- HTTPS 리스너: ACM *.dabom.site 인증서 적용

**HTTPS 리다이렉트:**

모든 HTTP:80 요청은 HTTPS:443으로 301 리다이렉트됩니다.

### modules/msk

Amazon MSK(Managed Streaming for Kafka) 클러스터를 관리합니다.

**클러스터 설정:**

- 카프카 버전: 3.6.0
- 브로커 인스턴스: kafka.t3.small x2
- 스토리지: 10GB gp3 (부트스트랩)
- 암호화: TLS_PLAINTEXT (VPC 내부는 평문, 외부는 TLS)

**카프카 커스텀 설정:**

```properties
auto.create.topics.enable=true
num.partitions=24
default.replication.factor=2
min.insync.replicas=1
log.retention.hours=168
```

**동작:**

- Producer가 메시지를 전송할 때 토픽이 없으면 자동 생성
- 24개 파티션으로 processor-usage의 최대 5 태스크 병렬 소비 대응
- 2 브로커 환경에서 복제 팩터 2 유지
- 로그 보존: 7일

### modules/elasticache

Redis 캐시 클러스터를 관리합니다.

- Redis 버전: 7
- 인스턴스 클래스: cache.t3.medium
- 노드 수: 1 (단일 노드, 클러스터 모드 비활성화)
- 자동 페일오버: 비활성화 (개발/스테이징 환경)

### modules/rds

MySQL 관계형 데이터베이스를 관리합니다.

**인스턴스 설정:**

- 엔진: MySQL 8.0
- 인스턴스 클래스: db.t3.small
- 스토리지: 20GB gp3, 자동 확장 최대 100GB
- 다중 AZ: 비활성화 (비용 절감)
- 공개 접근: true (보안그룹으로 제어)
- 백업 보관: 1일

**데이터베이스:**

- 데이터베이스명: app_db
- 사용자명: app_user
- 문자 인코딩: utf8mb4_unicode_ci (한국어/이모지 지원)
- 타임존: Asia/Seoul

**파라미터 튜닝:**

- max_connections: 150 (ECS 최대 11 태스크 x HikariCP 10 + 여유)
- wait_timeout: 300초 (좀비 커넥션 자동 정리)
- interactive_timeout: 300초

**비밀번호 관리:**

```hcl
lifecycle {
  ignore_changes = [password]  # 초기 생성 후 Terraform이 되돌리지 않음
}
```

RDS 비밀번호는 SSM Parameter Store에 저장되며, Terraform apply 후 콘솔 또는 CI/CD에서 관리됩니다.

### modules/parameter-store

SSM Parameter Store에서 모든 설정값을 중앙 관리합니다.

**SecureString 파라미터 (7개, KMS 암호화):**

| 파라미터 경로 | 설명 | 관리 방식 |
|--------------|------|---------|
| /dabom/db/password | RDS app_user 비밀번호 | ignore_changes |
| /dabom/db/root-password | RDS root 비밀번호 | ignore_changes |
| /dabom/jwt/secret-key | JWT 시크릿 키 | ignore_changes |
| /dabom/r2/access-key | Cloudflare R2 액세스 키 | terraform.tfvars |
| /dabom/r2/secret-key | Cloudflare R2 시크릿 키 | terraform.tfvars |
| /dabom/vapid/private-key | Web Push 비밀 키 | terraform.tfvars |
| /dabom/slack/webhook-url | Slack Webhook URL | terraform.tfvars |

**String 파라미터 (23개+):**

**DB 관련:**
- /dabom/db/url: JDBC 연결 문자열
- /dabom/db/name: 데이터베이스 이름
- /dabom/db/username: 데이터베이스 사용자명
- /dabom/db/root-password: RDS root 비밀번호

**Redis 관련:**
- /dabom/redis/host: 호스트명
- /dabom/redis/port: 포트 (6379)

**Kafka 관련:**
- /dabom/kafka/bootstrap-servers: 부트스트랩 브로커 주소
- /dabom/kafka/auto-offset-reset: 오프셋 리셋 정책
- /dabom/kafka/group-id/*: 소비자 그룹 ID
- /dabom/kafka/*-dedup-ttl: 중복 제거 TTL

**R2 관련:**
- /dabom/r2/endpoint: R2 엔드포인트
- /dabom/r2/bucket: 버킷명
- /dabom/r2/cdn-base-url: CDN URL

**VAPID:**
- /dabom/vapid/public-key: Web Push 공개 키

**OTEL:**
- /dabom/otel/sdk-disabled: SDK 비활성화 여부
- /dabom/otel/endpoint: OTLP 엔드포인트

**기타:**
- /dabom/spring/profile: Spring Profile (prod)
- /dabom/server/port: 서버 포트 (8080)
- /dabom/frontend-url: CORS 허용 출처

### modules/service-discovery

AWS Cloud Map을 통해 ECS 서비스 간 내부 DNS 레지스트리를 관리합니다.

**네임스페이스:**

- 이름: dabom.local (프라이빗 DNS)
- VPC: bootstrap에서 참조

**등록 서비스:**

- api-core.dabom.local
- processor-usage.dabom.local
- api-notification.dabom.local
- batch-core.dabom.local

### modules/autoscaling

ECS 서비스 CPU 기반 오토스케일링을 관리합니다.

**스케일링 정책:**

| 서비스 | Target CPU | Min | Max | Scale-out | Scale-in |
|--------|-----------|-----|-----|-----------|----------|
| api-core | 70% | 1 | 3 | 60초 | 300초 |
| processor-usage | 60% | 2 | 5 | 60초 | 300초 |
| api-notification | 70% | 1 | 2 | 60초 | 300초 |

**제외 서비스:**

- batch-core: 이벤트/스케줄 기반 실행이므로 오토스케일링 제외

### modules/cloudflare-dns

Cloudflare DNS 레코드를 관리합니다.

**DNS 레코드:**

| 레코드 | 타입 | 대상 | 목적 |
|--------|------|------|------|
| api.dabom.site | CNAME | alb-api DNS명 | REST API 진입점 |
| batch.dabom.site | CNAME | alb-api DNS명 | Batch 작업 진입점 |
| noti.dabom.site | CNAME | alb-noti DNS명 | 알림 서비스 진입점 |

**proxied 설정:**

- 모든 레코드: false (DNS Only)
- ACM 인증서로 ALB에서 직접 SSL 종료

### ACM 인증서 (루트 모듈)

와일드카드 HTTPS 인증서를 관리합니다.

- 도메인: *.dabom.site
- 검증 방식: DNS (Cloudflare에 자동 생성)
- 갱신: AWS 자동 관리
- ALB 리스너: alb-api, alb-noti에 적용

## 변수 (terraform.tfvars)

필수 및 선택 변수를 정의합니다.

### 프로젝트 기본값

| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| project | string | - | "dabom" | 리소스 네이밍 prefix |
| aws_region | string | - | "ap-northeast-2" | AWS 리전 |

### 필수 변수

| 변수 | 타입 | 설명 |
|------|------|------|
| cloudflare_zone_id | string | Cloudflare Zone ID (dabom.site) |
| tfc_organization | string | Terraform Cloud 조직명 |

### 선택 변수 (민감 정보)

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| monitor_eip | string | "" | 모니터링 VM EIP (비워두면 OTEL 자동 비활성화) |
| slack_webhook_url | string (sensitive) | "" | Slack Webhook URL (batch 알림용) |
| r2_access_key | string (sensitive) | "" | Cloudflare R2 액세스 키 |
| r2_secret_key | string (sensitive) | "" | Cloudflare R2 시크릿 키 |
| r2_endpoint | string | "" | Cloudflare R2 엔드포인트 |
| vapid_public_key | string | "" | VAPID 공개 키 |
| vapid_private_key | string (sensitive) | "" | VAPID 비밀 키 |
| frontend_url | string | "https://www.dabom.site,https://admin.dabom.site" | CORS 허용 출처 |

## 출력 (outputs)

apply 후 다음 값이 출력됩니다.

| 출력값 | 설명 |
|--------|------|
| ecs_cluster_name | ECS 클러스터 이름 |
| alb_api_dns_name | API ALB DNS 이름 |
| alb_noti_dns_name | Noti ALB DNS 이름 |
| msk_bootstrap_brokers | MSK 부트스트랩 브로커 주소 |
| elasticache_endpoint | Redis 엔드포인트 |
| rds_endpoint | RDS 엔드포인트 |

## 의존성

이 모듈은 bootstrap 레이어에 의존합니다.

**bootstrap에서 제공하는 출력:**

- vpc_id
- public_subnet_ids
- alb_sg_id
- ecs_sg_id
- rds_sg_id
- redis_sg_id
- msk_sg_id
- ecs_task_execution_role_arn
- ecs_task_role_arns (딕셔너리: api-core, processor-usage, api-notification, batch-core)
- ecr_repository_urls (딕셔너리: dabom/api-core, dabom/processor-usage, dabom/api-notification, dabom/batch-core)

**monitor 레이어와의 관계:**

- platform apply 이전에 monitor apply를 완료하고 EIP를 얻어야 합니다.
- monitor_eip를 platform의 terraform.tfvars에 입력하면 OTEL 엔드포인트로 활성화됩니다.
- monitor_eip가 비어있으면 OTEL_SDK_DISABLED=true로 설정됩니다.

## 배포 가이드

### 배포 순서

1. **bootstrap 레이어 apply** (필수)

   ```bash
   cd ../dabom-infra-bootstrap
   terraform apply
   ```

   VPC, 보안그룹, IAM, ECR이 생성됩니다.

2. **monitor 레이어 apply** (권장)

   ```bash
   cd ../dabom-infra-monitor
   terraform apply
   ```

   모니터링 VM이 생성되고 Elastic IP를 할당받습니다. 출력에서 EIP를 확인합니다.

3. **platform 레이어 apply**

   ```bash
   cd ../dabom-infra-platform
   terraform apply -var-file="terraform.tfvars"
   ```

   terraform.tfvars에서 monitor_eip를 입력합니다.

   ```hcl
   cloudflare_zone_id = "xxx"
   tfc_organization   = "yyy"
   monitor_eip        = "1.2.3.4"  # monitor 레이어의 출력에서 복사
   r2_access_key      = "..."
   r2_secret_key      = "..."
   r2_endpoint        = "https://xxx.r2.cloudflarestorage.com"
   vapid_public_key   = "..."
   vapid_private_key  = "..."
   slack_webhook_url  = "..."
   frontend_url       = "https://www.dabom.site,https://admin.dabom.site"
   ```

### terraform.tfvars 예시

```hcl
# 프로젝트 설정
project              = "dabom"
aws_region           = "ap-northeast-2"
cloudflare_zone_id   = "abc123def456"
tfc_organization     = "my-org"

# 선택 설정
monitor_eip          = "203.0.113.1"
frontend_url         = "https://www.dabom.site,https://admin.dabom.site"

# 민감 정보 (env var 또는 -var 플래그로 주입 권장)
slack_webhook_url    = "https://hooks.slack.com/services/..."
r2_access_key        = "abc123"
r2_secret_key        = "xyz789"
r2_endpoint          = "https://abc123.r2.cloudflarestorage.com"
vapid_public_key     = "BExxxx..."
vapid_private_key    = "xxxx..."
```

### 민감 정보 관리

환경변수 또는 terraform 명령어 플래그로 민감 정보를 주입하는 것을 권장합니다.

**방법 1: 환경변수**

```bash
export TF_VAR_slack_webhook_url="https://hooks.slack.com/..."
export TF_VAR_r2_access_key="abc123"
export TF_VAR_r2_secret_key="xyz789"
terraform apply -var-file="terraform.tfvars"
```

**방법 2: 플래그**

```bash
terraform apply \
  -var-file="terraform.tfvars" \
  -var="slack_webhook_url=..." \
  -var="r2_access_key=..." \
  -var="r2_secret_key=..."
```

**방법 3: Terraform Cloud (권장)**

Terraform Cloud 변수 설정에서 sensitive 플래그를 활성화하고 값을 입력합니다.

## 주요 설정 및 고려사항

### 데이터 레이어 서브넷 선택

RDS, ElastiCache, MSK는 **public_subnet_ids**를 사용합니다. NAT Gateway를 생성하지 않아 비용을 절감합니다. 보안그룹으로 접근을 제어하세요.

### 오토스케일링 비활성화

batch-core는 오토스케일링에서 제외됩니다. 이벤트 기반으로 실행되므로 항상 1 레플리카를 유지합니다.

### 로그 보관 기간

ECS CloudWatch 로그는 1일 보관합니다. 애플리케이션이 OTLP로 별도 전송하는 경우 충분합니다. 필요시 modules/ecs-service/main.tf에서 수정하세요.

```hcl
retention_in_days = 1  # 변경 가능
```

### RDS 다중 AZ 및 스케일업

현재 설정은 개발/스테이징용입니다. 프로덕션 전환 시:

- multi_az = true
- instance_class = "db.t3.medium" 이상
- allocated_storage = 50GB 이상

을 권장합니다.

### ElastiCache 클러스터 모드

현재 단일 노드 설정입니다. 높은 가용성이 필요한 경우:

```hcl
cluster_enabled = true
automatic_failover_enabled = true
num_cache_clusters = 3  # 최소 3
```

을 권장합니다.

### ACM 인증서 갱신

AWS에서 자동 갱신을 관리합니다. 만료 30일 전 자동으로 갱신됩니다. Cloudflare DNS 레코드가 계속 유지되어야 검증이 완료됩니다.

### Cloudflare DNS와 ACM 검증

cloudflare_record 리소스가 ACM 검증 레코드를 자동 생성합니다. 수동 개입이 필요 없으며, Terraform은 검증 완료 후에만 리소스 생성을 진행합니다.

### 컨테이너 이미지 버전 관리

모든 ECS 서비스는 latest 태그를 사용합니다:

```hcl
container_image = "${local.ecr_repository_urls["api-core"]}:latest"
```

이미지 업데이트 시 다음 명령어로 서비스를 재배포하세요:

```bash
aws ecs update-service \
  --cluster dabom-ecs-cluster \
  --service dabom-api-core \
  --force-new-deployment
```

또는 CI/CD 파이프라인에서 자동화하세요.

## 문제 해결

### ECS 서비스가 RUNNING 상태가 되지 않음

1. 로그 확인:

   ```bash
   aws logs tail /ecs/dabom/api-core --follow
   ```

2. 작업 정의 확인:

   ```bash
   aws ecs describe-task-definition --task-definition dabom-api-core
   ```

3. 헬스 체크 실패 확인:

   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-2:xxx:targetgroup/dabom-tg-api-core/xxx
   ```

### RDS 연결 실패

1. 보안그룹 확인:

   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxx
   ```

   ECS 보안그룹이 RDS 보안그룹의 3306 포트에 접근 가능해야 합니다.

2. 파라미터 스토어 확인:

   ```bash
   aws ssm get-parameter --name /dabom/db/url
   ```

3. RDS 상태 확인:

   ```bash
   aws rds describe-db-instances --db-instance-identifier dabom-rds-mysql
   ```

### MSK 브로커 연결 실패

1. 부트스트랩 브로커 주소 확인:

   ```bash
   aws kafka describe-cluster --cluster-arn arn:aws:kafka:ap-northeast-2:xxx:cluster/dabom-msk/xxx
   ```

2. 보안그룹 확인:

   ECS 보안그룹이 MSK 보안그룹의 9092, 9094 포트에 접근 가능해야 합니다.

### Cloudflare DNS 레코드 미동기화

1. Cloudflare 대시보드에서 레코드 확인:

   ```bash
   aws cloudflare-dns list-records --zone-id xxx
   ```

2. ALB DNS명 확인:

   ```bash
   aws elbv2 describe-load-balancers --names dabom-alb-api
   ```

3. 레코드 수동 갱신:

   ```bash
   terraform taint module.cloudflare_dns.cloudflare_record.api
   terraform apply
   ```

## 보안 권장사항

1. **RDS publicly_accessible 검토**

   현재 publicly_accessible=true이지만, 보안그룹으로 접근을 제어합니다. 프로덕션에서는 false로 설정하고 VPC 내부 접근만 허용하세요.

2. **민감 정보 저장소**

   terraform.tfvars에 민감 정보를 저장하지 마세요. Terraform Cloud나 환경변수를 사용하세요.

3. **IAM 권한 최소화**

   bootstrap에서 생성된 IAM 역할이 필요한 권한만 가지도록 검토하세요.

4. **네트워크 격리**

   RDS, ElastiCache, MSK가 public 서브넷을 사용하므로, 보안그룹 규칙을 엄격하게 유지하세요.

## 성능 튜닝

### ECS 리소스 조정

서비스별 CPU/Memory를 모니터링하고 필요시 조정하세요:

```bash
aws ecs describe-services --cluster dabom-ecs-cluster --services dabom-api-core
```

### 데이터베이스 커넥션 풀

RDS max_connections 및 ECS 서비스 HikariCP 설정을 확인하세요. 기본값:

- RDS max_connections: 150
- HikariCP maximumPoolSize: 10 (서비스별)
- 최대 동시 커넥션: 11 태스크 x 10 = 110

### Redis 메모리 관리

cache.t3.medium은 약 3GB 메모리입니다. MAXMEMORY 정책을 확인하세요.

### Kafka 파티션 및 소비자 그룹

num.partitions=24로 설정되었습니다. 토픽별로 필요에 따라 조정하세요:

```bash
aws kafka describe-cluster-operation --cluster-arn xxx --operation-arn xxx
```

## 추가 리소스

- [ECS 문서](https://docs.aws.amazon.com/ecs/)
- [RDS 문서](https://docs.aws.amazon.com/rds/)
- [MSK 문서](https://docs.aws.amazon.com/msk/)
- [CloudFlare DNS](https://developers.cloudflare.com/dns/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 라이센스

프로젝트 라이센스를 참고하세요.
