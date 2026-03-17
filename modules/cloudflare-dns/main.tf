terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Cloudflare DNS - ALB를 CNAME으로 가리키는 레코드 생성
# proxied=true: Cloudflare CDN/DDoS 보호 활성화

# api.dabom.site → API ALB
resource "cloudflare_record" "api" {
  zone_id = var.zone_id
  name    = "api"
  value   = var.alb_api_dns_name
  type    = "CNAME"
  proxied = true
}

# noti.dabom.site → Noti ALB (SSE 전용)
resource "cloudflare_record" "noti" {
  zone_id = var.zone_id
  name    = "noti"
  value   = var.alb_noti_dns_name
  type    = "CNAME"
  proxied = true
}
