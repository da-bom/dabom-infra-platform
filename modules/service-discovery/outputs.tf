output "namespace_id" {
  description = "서비스 디스커버리 네임스페이스 ID"
  value       = aws_service_discovery_private_dns_namespace.this.id
}

output "service_arns" {
  description = "서비스 디스커버리 서비스 ARN 맵 - ECS 서비스 등록에 사용"
  value       = { for k, v in aws_service_discovery_service.this : k => v.arn }
}
