output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = module.ecs_cluster.cluster_name
}

output "alb_api_dns_name" {
  description = "API ALB DNS 이름 - api.dabom.site CNAME 대상"
  value       = module.alb.alb_api_dns_name
}

output "alb_noti_dns_name" {
  description = "Noti ALB DNS 이름 - noti.dabom.site CNAME 대상"
  value       = module.alb.alb_noti_dns_name
}

output "msk_bootstrap_brokers" {
  description = "MSK 부트스트랩 브로커 주소"
  value       = module.msk.bootstrap_brokers
}

output "elasticache_endpoint" {
  description = "ElastiCache Redis 엔드포인트"
  value       = module.elasticache.endpoint
}

output "rds_endpoint" {
  description = "RDS MySQL 엔드포인트"
  value       = module.rds.endpoint
}
