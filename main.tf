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
}

# =============================================================================
# ALB - 외부 트래픽 진입점
# API ALB: 일반 REST, Noti ALB: SSE 장기 연결
# =============================================================================
module "alb" {
  source            = "./modules/alb"
  project           = var.project
  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids
  alb_sg_id         = local.alb_sg_id
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

# api-core: REST API, ALB 연결, 서비스 디스커버리 등록
module "ecs_service_api_core" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "api-core"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["api-core"]
  cpu                     = 512
  memory                  = 1024
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

  environment_variables = [
    { name = "SPRING_PROFILES_ACTIVE",                  value = "prod" },
    { name = "SERVER_PORT",                             value = "8080" },
    { name = "DATABASE_URL",                            value = "jdbc:mysql://${module.rds.address}:${module.rds.port}/app_db?serverTimezone=Asia/Seoul&characterEncoding=UTF-8" },
    { name = "DATABASE_NAME",                           value = "app_db" },
    { name = "DATABASE_USER",                           value = "app_user" },
    { name = "REDIS_HOST",                              value = module.elasticache.endpoint },
    { name = "REDIS_PORT",                              value = "6379" },
    { name = "KAFKA_BOOTSTRAP_SERVERS",                 value = module.msk.bootstrap_brokers },
    { name = "KAFKA_CONSUMER_GROUP_ID",                 value = "dabom-api-core" },
    { name = "KAFKA_AUTO_OFFSET_RESET",                 value = "earliest" },
    { name = "KAFKA_POLICY_DEDUP_TTL_SECONDS",          value = "3600" },
    { name = "KAFKA_USAGE_PERSIST_DEDUP_TTL_SECONDS",   value = "600" },
    { name = "FRONTEND_URL",                            value = "https://www.dabom.site,https://admin.dabom.site" },
    { name = "OTEL_TRACING_ENABLED",                    value = "true" },
    { name = "OTEL_SAMPLING_PROBABILITY",               value = "1.0" },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT",             value = "http://${var.monitor_eip}:4318/v1/traces" },
    { name = "JWT_ACCESS_TOKEN_EXPIRES_IN",             value = "720000000" },
    { name = "JWT_REFRESH_TOKEN_EXPIRES_IN",            value = "1209600000" },
    { name = "R2_ENDPOINT",                             value = "https://placeholder.r2.cloudflarestorage.com" },
    { name = "R2_BUCKET",                               value = "dabom-storage" },
    { name = "R2_CDN_BASE_URL",                         value = "https://cdn.dabom.site" },
  ]

  secrets = [
    { name = "DATABASE_PASSWORD",      valueFrom = module.parameter_store.parameter_arns["db_password"] },
    { name = "DATABASE_ROOT_PASSWORD", valueFrom = module.parameter_store.parameter_arns["db_root_password"] },
    { name = "JWT_SECRET_KEY",         valueFrom = module.parameter_store.parameter_arns["jwt_secret_key"] },
    { name = "R2_ACCESS_KEY",          valueFrom = module.parameter_store.parameter_arns["r2_access_key"] },
    { name = "R2_SECRET_KEY",          valueFrom = module.parameter_store.parameter_arns["r2_secret_key"] },
  ]
}

# processor-usage: Kafka 소비자, ALB 없음, 높은 처리량을 위해 스케일 아웃
module "ecs_service_processor_usage" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "processor-usage"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["processor-usage"]
  cpu                     = 256
  memory                  = 512
  desired_count           = 2
  container_image         = "${local.ecr_repository_urls["processor-usage"]}:latest"
  container_port          = 8080
  subnet_ids              = local.public_subnet_ids
  security_group_ids      = [local.ecs_sg_id]
  assign_public_ip        = true
  enable_load_balancer    = false
  service_discovery_arn   = module.service_discovery.service_arns["processor-usage"]

  environment_variables = [
    { name = "SPRING_PROFILES_ACTIVE",                value = "prod" },
    { name = "SERVER_PORT",                           value = "8080" },
    { name = "DATABASE_URL",                          value = "jdbc:mysql://${module.rds.address}:${module.rds.port}/app_db?serverTimezone=Asia/Seoul&characterEncoding=UTF-8" },
    { name = "DATABASE_NAME",                         value = "app_db" },
    { name = "DATABASE_USER",                         value = "app_user" },
    { name = "REDIS_HOST",                            value = module.elasticache.endpoint },
    { name = "REDIS_PORT",                            value = "6379" },
    { name = "KAFKA_BOOTSTRAP_SERVERS",               value = module.msk.bootstrap_brokers },
    { name = "KAFKA_CONSUMER_GROUP_ID",               value = "dabom-processor-usage" },
    { name = "KAFKA_AUTO_OFFSET_RESET",               value = "earliest" },
    { name = "KAFKA_USAGE_PERSIST_DEDUP_TTL_SECONDS", value = "600" },
    { name = "OTEL_TRACING_ENABLED",                  value = "true" },
    { name = "OTEL_SAMPLING_PROBABILITY",             value = "1.0" },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT",           value = "http://${var.monitor_eip}:4318/v1/traces" },
  ]

  secrets = [
    { name = "DATABASE_PASSWORD", valueFrom = module.parameter_store.parameter_arns["db_password"] },
    { name = "JWT_SECRET_KEY",    valueFrom = module.parameter_store.parameter_arns["jwt_secret_key"] },
  ]
}

# api-notification: SSE 기반 알림 서비스, Noti ALB 연결, VAPID 키 필요
module "ecs_service_api_notification" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "api-notification"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["api-notification"]
  cpu                     = 512
  memory                  = 1024
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
    { name = "SPRING_PROFILES_ACTIVE",      value = "prod" },
    { name = "SERVER_PORT",                 value = "8080" },
    { name = "DATABASE_URL",                value = "jdbc:mysql://${module.rds.address}:${module.rds.port}/app_db?serverTimezone=Asia/Seoul&characterEncoding=UTF-8" },
    { name = "DATABASE_NAME",               value = "app_db" },
    { name = "DATABASE_USER",               value = "app_user" },
    { name = "REDIS_HOST",                  value = module.elasticache.endpoint },
    { name = "REDIS_PORT",                  value = "6379" },
    { name = "KAFKA_BOOTSTRAP_SERVERS",     value = module.msk.bootstrap_brokers },
    { name = "KAFKA_CONSUMER_GROUP_ID",     value = "dabom-api-notification" },
    { name = "KAFKA_AUTO_OFFSET_RESET",     value = "earliest" },
    { name = "FRONTEND_URL",                value = "https://www.dabom.site,https://admin.dabom.site" },
    { name = "OTEL_TRACING_ENABLED",        value = "true" },
    { name = "OTEL_SAMPLING_PROBABILITY",   value = "1.0" },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://${var.monitor_eip}:4318/v1/traces" },
  ]

  secrets = [
    { name = "DATABASE_PASSWORD", valueFrom = module.parameter_store.parameter_arns["db_password"] },
    { name = "JWT_SECRET_KEY",    valueFrom = module.parameter_store.parameter_arns["jwt_secret_key"] },
    { name = "VAPID_PRIVATE_KEY", valueFrom = module.parameter_store.parameter_arns["vapid_private_key"] },
  ]
}

# batch-core: 배치 작업 서비스, ALB/오토스케일링 없음, Spring Batch + @Scheduled 내장
module "ecs_service_batch_core" {
  source = "./modules/ecs-service"

  project                 = var.project
  service_name            = "batch-core"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = local.ecs_task_execution_role_arn
  task_role_arn           = local.ecs_task_role_arns["batch-core"]
  cpu                     = 256
  memory                  = 512
  desired_count           = 1
  container_image         = "${local.ecr_repository_urls["batch-core"]}:latest"
  container_port          = 8080
  subnet_ids              = local.public_subnet_ids
  security_group_ids      = [local.ecs_sg_id]
  assign_public_ip        = true
  enable_load_balancer    = false
  service_discovery_arn   = module.service_discovery.service_arns["batch-core"]

  environment_variables = [
    { name = "SPRING_PROFILES_ACTIVE",      value = "prod" },
    { name = "SERVER_PORT",                 value = "8080" },
    { name = "DATABASE_URL",                value = "jdbc:mysql://${module.rds.address}:${module.rds.port}/app_db?serverTimezone=Asia/Seoul&characterEncoding=UTF-8" },
    { name = "DATABASE_NAME",               value = "app_db" },
    { name = "DATABASE_USER",               value = "app_user" },
    { name = "REDIS_HOST",                  value = module.elasticache.endpoint },
    { name = "REDIS_PORT",                  value = "6379" },
    { name = "KAFKA_BOOTSTRAP_SERVERS",     value = module.msk.bootstrap_brokers },
    { name = "OTEL_TRACING_ENABLED",        value = "true" },
    { name = "OTEL_SAMPLING_PROBABILITY",   value = "1.0" },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://${var.monitor_eip}:4318/v1/traces" },
  ]

  secrets = [
    { name = "DATABASE_PASSWORD", valueFrom = module.parameter_store.parameter_arns["db_password"] },
    { name = "JWT_SECRET_KEY",    valueFrom = module.parameter_store.parameter_arns["jwt_secret_key"] },
  ]
}

# =============================================================================
# 오토스케일링 - API/처리 서비스 CPU 기반 스케일링
# batch 제외 (이벤트 기반 실행)
# =============================================================================
module "autoscaling" {
  source       = "./modules/autoscaling"
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
# Cloudflare DNS - ALB를 도메인에 연결
# api.dabom.site, noti.dabom.site
# =============================================================================
module "cloudflare_dns" {
  source            = "./modules/cloudflare-dns"
  zone_id           = var.cloudflare_zone_id
  alb_api_dns_name  = module.alb.alb_api_dns_name
  alb_noti_dns_name = module.alb.alb_noti_dns_name
}
