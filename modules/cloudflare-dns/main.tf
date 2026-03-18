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
# proxied=false (DNS Only): API는 CDN 캐싱 불필요, Cloudflare Proxy가 CORS preflight를 간섭할 수 있음
resource "cloudflare_record" "api" {
  zone_id = var.zone_id
  name    = "api"
  content = var.alb_api_dns_name
  type    = "CNAME"
  proxied = false
}

# batch.dabom.site → API ALB (batch-core, 호스트 기반 라우팅)
resource "cloudflare_record" "batch" {
  zone_id = var.zone_id
  name    = "batch"
  content = var.alb_api_dns_name
  type    = "CNAME"
  proxied = false
}

# noti.dabom.site → Noti ALB (SSE 전용)
# proxied=false: SSE 장기 연결 + CORS 호환성을 위해 DNS Only
resource "cloudflare_record" "noti" {
  zone_id = var.zone_id
  name    = "noti"
  content = var.alb_noti_dns_name
  type    = "CNAME"
  proxied = false
}
