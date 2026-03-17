variable "zone_id" {
  description = "Cloudflare Zone ID - dabom.site 도메인"
  type        = string
}

variable "alb_api_dns_name" {
  description = "API ALB DNS 이름 - CNAME 레코드 값"
  type        = string
}

variable "alb_noti_dns_name" {
  description = "Noti ALB DNS 이름 - CNAME 레코드 값"
  type        = string
}
