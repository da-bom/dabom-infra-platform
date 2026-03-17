# RDS root 비밀번호 랜덤 생성
resource "random_password" "rds_root" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}:?"
}

# JWT 시크릿 키 랜덤 생성 (UUID 기반)
resource "random_uuid" "jwt_secret" {}

# =============================================================================
# SecureString 파라미터 - 민감 정보, KMS 암호화
# lifecycle ignore_changes = [value] 적용 - 초기 생성 후 콘솔/CI에서 관리
# =============================================================================

resource "aws_ssm_parameter" "db_password" {
  name  = "/dabom/db/password"
  type  = "SecureString"
  value = var.rds_password

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "db_root_password" {
  name  = "/dabom/db/root-password"
  type  = "SecureString"
  value = random_password.rds_root.result

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "jwt_secret_key" {
  name  = "/dabom/jwt/secret-key"
  type  = "SecureString"
  value = random_uuid.jwt_secret.result

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "r2_access_key" {
  name  = "/dabom/r2/access-key"
  type  = "SecureString"
  value = var.r2_access_key
}

resource "aws_ssm_parameter" "r2_secret_key" {
  name  = "/dabom/r2/secret-key"
  type  = "SecureString"
  value = var.r2_secret_key
}

resource "aws_ssm_parameter" "vapid_private_key" {
  name  = "/dabom/vapid/private-key"
  type  = "SecureString"
  value = var.vapid_private_key
}

# =============================================================================
# String 파라미터 - 비민감 설정값
# =============================================================================

resource "aws_ssm_parameter" "spring_profile" {
  name  = "/dabom/spring/profile"
  type  = "String"
  value = "prod"
}

resource "aws_ssm_parameter" "server_port" {
  name  = "/dabom/server/port"
  type  = "String"
  value = "8080"
}

resource "aws_ssm_parameter" "db_url" {
  name  = "/dabom/db/url"
  type  = "String"
  value = "jdbc:mysql://${var.rds_endpoint}/app_db?serverTimezone=Asia/Seoul&characterEncoding=UTF-8"
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/dabom/db/name"
  type  = "String"
  value = "app_db"
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/dabom/db/username"
  type  = "String"
  value = "app_user"
}

resource "aws_ssm_parameter" "redis_host" {
  name  = "/dabom/redis/host"
  type  = "String"
  value = var.redis_endpoint
}

resource "aws_ssm_parameter" "redis_port" {
  name  = "/dabom/redis/port"
  type  = "String"
  value = "6379"
}

resource "aws_ssm_parameter" "kafka_bootstrap_servers" {
  name  = "/dabom/kafka/bootstrap-servers"
  type  = "String"
  value = var.msk_bootstrap_brokers
}

resource "aws_ssm_parameter" "kafka_group_id_api_core" {
  name  = "/dabom/kafka/group-id/api-core"
  type  = "String"
  value = "dabom-api-core"
}

resource "aws_ssm_parameter" "kafka_group_id_proc_usage" {
  name  = "/dabom/kafka/group-id/proc-usage"
  type  = "String"
  value = "dabom-processor-usage"
}

resource "aws_ssm_parameter" "kafka_group_id_api_noti" {
  name  = "/dabom/kafka/group-id/api-noti"
  type  = "String"
  value = "dabom-api-notification"
}

resource "aws_ssm_parameter" "kafka_auto_offset_reset" {
  name  = "/dabom/kafka/auto-offset-reset"
  type  = "String"
  value = "earliest"
}

resource "aws_ssm_parameter" "kafka_policy_dedup_ttl" {
  name  = "/dabom/kafka/policy-dedup-ttl"
  type  = "String"
  value = "3600"
}

resource "aws_ssm_parameter" "kafka_usage_persist_dedup_ttl" {
  name  = "/dabom/kafka/usage-persist-dedup-ttl"
  type  = "String"
  value = "600"
}

resource "aws_ssm_parameter" "cors_frontend_url" {
  name  = "/dabom/cors/frontend-url"
  type  = "String"
  value = var.frontend_url
}

resource "aws_ssm_parameter" "otel_enabled" {
  name  = "/dabom/otel/enabled"
  type  = "String"
  value = "true"
}

resource "aws_ssm_parameter" "otel_sampling" {
  name  = "/dabom/otel/sampling"
  type  = "String"
  value = "1.0"
}

resource "aws_ssm_parameter" "otel_endpoint" {
  name  = "/dabom/otel/endpoint"
  type  = "String"
  value = "http://${var.monitor_eip}:4318/v1/traces"
}

resource "aws_ssm_parameter" "jwt_access_expires" {
  name  = "/dabom/jwt/access-expires"
  type  = "String"
  value = "720000000"
}

resource "aws_ssm_parameter" "jwt_refresh_expires" {
  name  = "/dabom/jwt/refresh-expires"
  type  = "String"
  value = "1209600000"
}

resource "aws_ssm_parameter" "r2_endpoint" {
  name  = "/dabom/r2/endpoint"
  type  = "String"
  value = var.r2_endpoint
}

resource "aws_ssm_parameter" "r2_bucket" {
  name  = "/dabom/r2/bucket"
  type  = "String"
  value = "dabom-storage"
}

resource "aws_ssm_parameter" "r2_cdn_base_url" {
  name  = "/dabom/r2/cdn-base-url"
  type  = "String"
  value = "https://cdn.dabom.site"
}

resource "aws_ssm_parameter" "vapid_public_key" {
  name  = "/dabom/vapid/public-key"
  type  = "String"
  value = var.vapid_public_key
}
