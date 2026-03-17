variable "project" {
  description = "프로젝트 이름 - 리소스 네이밍 prefix"
  type        = string
  default     = "dabom"
}

variable "aws_region" {
  description = "AWS 리전 - 서울 리전 사용"
  type        = string
  default     = "ap-northeast-2"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID - dabom.site 도메인 존"
  type        = string
}

variable "tfc_organization" {
  description = "Terraform Cloud 조직 이름"
  type        = string
}

variable "monitor_eip" {
  description = "모니터링 VM의 Elastic IP - OTLP 엔드포인트용 (monitor 배포 후 업데이트). 비워두면 OTEL 자동 비활성화."
  type        = string
  default     = ""
}

# ─── Cloudflare R2 ───
variable "r2_access_key" {
  description = "Cloudflare R2 Access Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "r2_secret_key" {
  description = "Cloudflare R2 Secret Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "r2_endpoint" {
  description = "Cloudflare R2 endpoint (https://<account-id>.r2.cloudflarestorage.com)"
  type        = string
  default     = ""
}

# ─── VAPID (Web Push) ───
variable "vapid_public_key" {
  description = "VAPID public key for web push notifications"
  type        = string
  default     = ""
}

variable "vapid_private_key" {
  description = "VAPID private key for web push notifications"
  type        = string
  sensitive   = true
  default     = ""
}
