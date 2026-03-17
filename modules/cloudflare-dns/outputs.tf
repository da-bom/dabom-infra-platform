output "api_record_hostname" {
  description = "API DNS 레코드 호스트명"
  value       = cloudflare_record.api.hostname
}

output "noti_record_hostname" {
  description = "Noti DNS 레코드 호스트명"
  value       = cloudflare_record.noti.hostname
}
