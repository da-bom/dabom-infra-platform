# =============================================================================
# ECS 클러스터 - 모든 서비스의 실행 기반
# =============================================================================
module "ecs_cluster" {
  source  = "./modules/ecs-cluster"
  project = var.project
}

# =============================================================================
# 데이터 레이어 - RDS, ElastiCache, MSK
# 퍼블릭 서브넷 사용 (비용 절감 - NAT Gateway 없음)
# =============================================================================
module "rds" {
  source    = "./modules/rds"
  project   = var.project
  subnet_ids = local.public_subnet_ids
  rds_sg_id  = local.rds_sg_id
}

module "elasticache" {
  source      = "./modules/elasticache"
  project     = var.project
  subnet_ids  = local.public_subnet_ids
  redis_sg_id = local.redis_sg_id
}

module "msk" {
  source     = "./modules/msk"
  project    = var.project
  subnet_ids = local.public_subnet_ids
  msk_sg_id  = local.msk_sg_id
}

# =============================================================================
# SSM Parameter Store - 모든 서비스 설정값 중앙 관리
# RDS, Redis, MSK 배포 완료 후 값 주입
# =============================================================================
module "parameter_store" {
  source = "./modules/parameter-store"

  rds_endpoint           = module.rds.address
  rds_password           = module.rds.password
  redis_endpoint         = module.elasticache.endpoint
  msk_bootstrap_brokers  = module.msk.bootstrap_brokers
  monitor_eip            = var.monitor_eip
  r2_access_key          = var.r2_access_key
  r2_secret_key          = var.r2_secret_key
  r2_endpoint            = var.r2_endpoint
  vapid_public_key       = var.vapid_public_key
  vapid_private_key      = var.vapid_private_key
  frontend_url           = var.frontend_url
  slack_webhook_url      = var.slack_webhook_url
}

# 공통 secrets - Parameter Store에서 주입 (전체 서비스 공유)
locals {
  p = module.parameter_store.parameter_arns

  # 모든 서비스가 공유하는 공통 secrets
  common_secrets = [
    { name = "DATABASE_URL",      valueFrom = local.p["db_url"] },
    { name = "DATABASE_USER",     valueFrom = local.p["db_username"] },
    { name = "DATABASE_PASSWORD", valueFrom = local.p["db_password"] },
    { name = "REDIS_HOST",        valueFrom = local.p["redis_host"] },
    { name = "REDIS_PORT",        valueFrom = local.p["redis_port"] },
    { name = "OTEL_SDK_DISABLED",            valueFrom = local.p["otel_sdk_disabled"] },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", valueFrom = local.p["otel_endpoint"] },
  ]

  # Kafka를 사용하는 서비스의 공통 secrets (api-core, proc-usage, api-noti)
  kafka_common_secrets = [
    { name = "KAFKA_BOOTSTRAP_SERVERS",              valueFrom = local.p["kafka_bootstrap_servers"] },
    { name = "KAFKA_AUTO_OFFSET_RESET",              valueFrom = local.p["kafka_auto_offset_reset"] },
    { name = "KAFKA_POLICY_DEDUP_TTL_SECONDS",       valueFrom = local.p["kafka_policy_dedup_ttl"] },
    { name = "KAFKA_USAGE_PERSIST_DEDUP_TTL_SECONDS", valueFrom = local.p["kafka_usage_persist_dedup_ttl"] },
  ]

  # JWT를 사용하는 서비스의 공통 secrets (api-core, api-noti)
  jwt_secrets = [
    { name = "JWT_SECRET_KEY",             valueFrom = local.p["jwt_secret_key"] },
    { name = "JWT_ACCESS_TOKEN_EXPIRES_IN", valueFrom = local.p["jwt_access_expires"] },
    { name = "JWT_REFRESH_TOKEN_EXPIRES_IN", valueFrom = local.p["jwt_refresh_expires"] },
  ]

  # CORS를 사용하는 서비스의 공통 secrets (api-core, proc-usage, api-noti)
  cors_secrets = [
    { name = "FRONTEND_URL", valueFrom = local.p["frontend_url"] },
  ]
}

# =============================================================================
# ALB - 외부 트래픽 진입점
# API ALB: 일반 REST, Noti ALB: SSE 장기 연결
# =============================================================================
module "alb" {
  source              = "./modules/alb"
  project             = var.project
  vpc_id              = local.vpc_id
  public_subnet_ids   = local.public_subnet_ids
  alb_sg_id           = local.alb_sg_id
  acm_certificate_arn = aws_acm_certificate_validation.wildcard.certificate_arn
}

# =============================================================================
# 서비스 디스커버리 - ECS 서비스 간 내부 통신 (dabom.local)
# =============================================================================
module "service_discovery" {
  source  = "./modules/service-discovery"
  project = var.project
  vpc_id  = local.vpc_id
}

# =============================================================================
# ECS 서비스 - 4개 마이크로서비스
# ECR 이미지: bootstrap 레이어에서 생성된 레포지토리 사용
# =============================================================================

# api-core: REST API, ALB 연결
module "ecs_service_api_core" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "api-core"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["api-core"]
  cpu                     = 1024
  memory                  = 2048
  desired_count           = 1
  container_image         = "${local.ecr_repository_urls["api-core"]}:latest"
  container_port          = 8080
  subnet_ids              = local.public_subnet_ids
  security_group_ids      = [local.ecs_sg_id]
  assign_public_ip        = true
  enable_load_balancer    = true
  target_group_arn        = module.alb.tg_api_core_arn
  health_check_path       = "/actuator/health"
  service_discovery_arn   = module.service_discovery.service_arns["api-core"]

  # 서비스 고유값만 environment에 유지
  environment_variables = [
    { name = "SPRING_PROFILES_ACTIVE",          value = "prod" },
    { name = "SERVER_PORT",                     value = "8080" },
    { name = "SERVER_FORWARD_HEADERS_STRATEGY", value = "framework" },
    { name = "DATABASE_NAME",                   value = "app_db" },
  ]

  # 공통값 + 서비스별 고유 secrets를 Parameter Store에서 주입
  secrets = concat(
    local.common_secrets,
    local.kafka_common_secrets,
    local.jwt_secrets,
    local.cors_secrets,
    [
      { name = "KAFKA_CONSUMER_GROUP_ID",  valueFrom = local.p["kafka_group_id_api_core"] },
      { name = "DATABASE_ROOT_PASSWORD",   valueFrom = local.p["db_root_password"] },
      { name = "R2_ENDPOINT",              valueFrom = local.p["r2_endpoint"] },
      { name = "R2_ACCESS_KEY",            valueFrom = local.p["r2_access_key"] },
      { name = "R2_SECRET_KEY",            valueFrom = local.p["r2_secret_key"] },
      { name = "R2_BUCKET",                valueFrom = local.p["r2_bucket"] },
      { name = "R2_CDN_BASE_URL",          valueFrom = local.p["r2_cdn_base_url"] },
    ]
  )
}

# processor-usage: Kafka 소비자, ALB 없음
module "ecs_service_processor_usage" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "processor-usage"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["processor-usage"]
  cpu                     = 512
  memory                  = 1024
  desired_count           = 2
  container_image         = "${local.ecr_repository_urls["processor-usage"]}:latest"
  container_port          = 8080
  subnet_ids              = local.public_subnet_ids
  security_group_ids      = [local.ecs_sg_id]
  assign_public_ip        = true
  enable_load_balancer    = false
  service_discovery_arn   = module.service_discovery.service_arns["processor-usage"]

  environment_variables = [
    { name = "SPRING_PROFILES_ACTIVE",          value = "prod" },
    { name = "SERVER_PORT",                     value = "8080" },
    { name = "SERVER_FORWARD_HEADERS_STRATEGY", value = "framework" },
  ]

  secrets = concat(
    local.common_secrets,
    local.kafka_common_secrets,
    local.cors_secrets,
    [
      { name = "KAFKA_CONSUMER_GROUP_ID", valueFrom = local.p["kafka_group_id_proc_usage"] },
    ]
  )
}

# api-notification: SSE 기반 알림 서비스, Noti ALB 연결
module "ecs_service_api_notification" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "api-notification"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["api-notification"]
  cpu                     = 1024
  memory                  = 2048
  desired_count           = 1
  container_image         = "${local.ecr_repository_urls["api-notification"]}:latest"
  container_port          = 8080
  subnet_ids              = local.public_subnet_ids
  security_group_ids      = [local.ecs_sg_id]
  assign_public_ip        = true
  enable_load_balancer    = true
  target_group_arn        = module.alb.tg_api_noti_arn
  health_check_path       = "/actuator/health"
  service_discovery_arn   = module.service_discovery.service_arns["api-notification"]

  environment_variables = [
    { name = "SPRING_PROFILES_ACTIVE",          value = "prod" },
    { name = "SERVER_PORT",                     value = "8080" },
    { name = "SERVER_FORWARD_HEADERS_STRATEGY", value = "framework" },
    { name = "DATABASE_NAME",                   value = "app_db" },
  ]

  secrets = concat(
    local.common_secrets,
    local.kafka_common_secrets,
    local.jwt_secrets,
    local.cors_secrets,
    [
      { name = "KAFKA_CONSUMER_GROUP_ID", valueFrom = local.p["kafka_group_id_api_noti"] },
      { name = "VAPID_PUBLIC_KEY",        valueFrom = local.p["vapid_public_key"] },
      { name = "VAPID_PRIVATE_KEY",       valueFrom = local.p["vapid_private_key"] },
    ]
  )
}

# batch-core: Spring Batch + @Scheduled 내장, ALB/오토스케일링 없음
module "ecs_service_batch_core" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "batch-core"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["batch-core"]
  cpu                     = 1024
  memory                  = 2048
  desired_count           = 1
  container_image         = "${local.ecr_repository_urls["batch-core"]}:latest"
  container_port          = 8080
  subnet_ids              = local.public_subnet_ids
  security_group_ids      = [local.ecs_sg_id]
  assign_public_ip        = true
  enable_load_balancer    = true
  target_group_arn        = module.alb.tg_batch_core_arn
  health_check_path       = "/actuator/health"
  service_discovery_arn   = module.service_discovery.service_arns["batch-core"]

  # batch-core 고유값 (BATCH_* 스케줄/튜닝 + Redis 추가설정)
  environment_variables = [
    { name = "SPRING_PROFILES_ACTIVE",  value = "prod" },
    { name = "REDIS_PASSWORD",          value = "" },
    { name = "REDIS_SSL_ENABLED",       value = "false" },
    # --- Batch Global ---
    { name = "BATCH_JOB_ENABLED",          value = "false" },
    { name = "BATCH_RETRY_LIMIT",          value = "3" },
    { name = "BATCH_RETRY_BACKOFF_MILLIS", value = "3000" },
    # --- Schedule ---
    { name = "BATCH_WEEKLY_FAMILY_RECAP_ENABLED",        value = "false" },
    { name = "BATCH_WEEKLY_FAMILY_RECAP_CRON",           value = "0 10 0 * * MON" },
    { name = "BATCH_MONTHLY_FAMILY_RECAP_ENABLED",       value = "false" },
    { name = "BATCH_MONTHLY_FAMILY_RECAP_CRON",          value = "0 20 0 1 * *" },
    { name = "BATCH_MONTHLY_USAGE_PRECREATE_ENABLED",    value = "false" },
    { name = "BATCH_MONTHLY_USAGE_PRECREATE_CRON",       value = "0 30 23 28-31 * *" },
    { name = "BATCH_MONTHLY_USAGE_RESET_ENABLED",        value = "false" },
    { name = "BATCH_MONTHLY_USAGE_RESET_CRON",           value = "0 1 0 1 * *" },
    { name = "BATCH_DB_REDIS_RECONCILIATION_ENABLED",    value = "false" },
    { name = "BATCH_DB_REDIS_RECONCILIATION_CRON",       value = "0 0 3 * * *" },
    { name = "BATCH_EVENT_OUTBOX_ENABLED",         value = "false" },
    { name = "BATCH_EVENT_OUTBOX_FIXED_DELAY",     value = "60000" },
    { name = "BATCH_EVENT_OUTBOX_INITIAL_DELAY",   value = "5000" },
    # --- Tuning ---
    { name = "BATCH_WEEKLY_FAMILY_RECAP_LOCK_TTL",              value = "PT1H" },
    { name = "BATCH_WEEKLY_FAMILY_RECAP_CHUNK_SIZE",            value = "500" },
    { name = "BATCH_WEEKLY_FAMILY_RECAP_DB_FETCH_SIZE",         value = "1000" },
    { name = "BATCH_MONTHLY_FAMILY_RECAP_LOCK_TTL",             value = "PT1H" },
    { name = "BATCH_MONTHLY_FAMILY_RECAP_CHUNK_SIZE",           value = "500" },
    { name = "BATCH_MONTHLY_FAMILY_RECAP_DB_FETCH_SIZE",        value = "1000" },
    { name = "BATCH_MONTHLY_USAGE_PRECREATE_LOCK_TTL",          value = "PT1H" },
    { name = "BATCH_MONTHLY_USAGE_PRECREATE_DB_FETCH_SIZE",     value = "4000" },
    { name = "BATCH_MONTHLY_USAGE_RESET_LOCK_TTL",              value = "PT1H" },
    { name = "BATCH_MONTHLY_USAGE_RESET_REDIS_CHUNK_SIZE",      value = "2000" },
    { name = "BATCH_MONTHLY_USAGE_RESET_DB_FETCH_SIZE",         value = "4000" },
    { name = "BATCH_DB_REDIS_RECONCILIATION_LOCK_TTL",          value = "PT1H" },
    { name = "BATCH_DB_REDIS_RECONCILIATION_REDIS_CHUNK_SIZE",  value = "2000" },
    { name = "BATCH_DB_REDIS_RECONCILIATION_DB_FETCH_SIZE",     value = "4000" },
    { name = "BATCH_EVENT_OUTBOX_BATCH_SIZE",              value = "100" },
    { name = "BATCH_EVENT_OUTBOX_CONCURRENCY",             value = "8" },
    { name = "BATCH_EVENT_OUTBOX_MAX_RETRY",               value = "5" },
    { name = "BATCH_EVENT_OUTBOX_RETRY_INITIAL_DELAY",     value = "PT1M" },
    { name = "BATCH_EVENT_OUTBOX_RETRY_MAX_DELAY",         value = "PT16M" },
    { name = "BATCH_EVENT_OUTBOX_RETRY_ELIGIBILITY_DELAY", value = "PT1M" },
    { name = "BATCH_EVENT_OUTBOX_PUBLISH_TIMEOUT",         value = "PT10S" },
  ]

  # 공통값은 Parameter Store에서 주입, batch-core 고유 secrets 추가
  secrets = concat(
    local.common_secrets,
    [
      { name = "KAFKA_BOOTSTRAP_SERVERS", valueFrom = local.p["kafka_bootstrap_servers"] },
      { name = "SLACK_WEBHOOK_URL",       valueFrom = local.p["slack_webhook_url"] },
    ]
  )
}

# =============================================================================
# 오토스케일링 - API/처리 서비스 CPU 기반 스케일링
# batch 제외 (이벤트 기반 실행)
# =============================================================================
module "autoscaling" {
  source       = "./modules/autoscaling"
  project      = var.project
  cluster_name = module.ecs_cluster.cluster_name

  services = {
    "api-core" = {
      min        = 1
      max        = 3
      target_cpu = 70
    }
    "processor-usage" = {
      min        = 2
      max        = 5
      target_cpu = 60
    }
    "api-notification" = {
      min        = 1
      max        = 2
      target_cpu = 70
    }
  }

  depends_on = [
    module.ecs_service_api_core,
    module.ecs_service_processor_usage,
    module.ecs_service_api_notification,
  ]
}

# =============================================================================
# ACM 인증서 - *.dabom.site 와일드카드 (무료, DNS 검증)
# =============================================================================
resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.dabom.site"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Cloudflare에 ACM DNS 검증 레코드 생성
resource "cloudflare_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.value
  proxied = false
}

# 검증 완료 대기
resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn = aws_acm_certificate.wildcard.arn
}

# =============================================================================
# Cloudflare DNS - ALB를 도메인에 연결
# api.dabom.site, noti.dabom.site
# =============================================================================
module "cloudflare_dns" {
  source            = "./modules/cloudflare-dns"
  zone_id           = var.cloudflare_zone_id
  alb_api_dns_name  = module.alb.alb_api_dns_name
  alb_noti_dns_name = module.alb.alb_noti_dns_name
}
