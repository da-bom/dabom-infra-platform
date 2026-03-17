variable "rds_endpoint" {
  description = "RDS 엔드포인트 주소 - JDBC URL 구성에 사용"
  type        = string
}

variable "rds_password" {
  description = "RDS 애플리케이션 사용자 비밀번호"
  type        = string
  sensitive   = true
}

variable "redis_endpoint" {
  description = "ElastiCache Redis 엔드포인트 주소"
  type        = string
}

variable "msk_bootstrap_brokers" {
  description = "MSK 부트스트랩 브로커 주소 목록"
  type        = string
}

variable "monitor_eip" {
  description = "모니터링 VM EIP - OTLP 엔드포인트 구성"
  type        = string
}
