output "alb_api_arn" {
  description = "API ALB ARN"
  value       = aws_lb.api.arn
}

output "alb_api_dns_name" {
  description = "API ALB DNS 이름 - Cloudflare CNAME 레코드에 사용"
  value       = aws_lb.api.dns_name
}

output "tg_api_core_arn" {
  description = "api-core 타겟 그룹 ARN - ECS 서비스 연결"
  value       = aws_lb_target_group.api_core.arn
}

output "tg_batch_core_arn" {
  description = "batch-core 타겟 그룹 ARN - ECS 서비스 연결"
  value       = aws_lb_target_group.batch_core.arn
}

output "alb_noti_arn" {
  description = "Noti ALB ARN"
  value       = aws_lb.noti.arn
}

output "alb_noti_dns_name" {
  description = "Noti ALB DNS 이름 - Cloudflare CNAME 레코드에 사용"
  value       = aws_lb.noti.dns_name
}

output "tg_api_noti_arn" {
  description = "api-noti 타겟 그룹 ARN - ECS 서비스 연결"
  value       = aws_lb_target_group.api_noti.arn
}
