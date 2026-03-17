output "endpoint" {
  description = "Redis 엔드포인트 주소"
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "port" {
  description = "Redis 포트"
  value       = aws_elasticache_cluster.this.port
}
