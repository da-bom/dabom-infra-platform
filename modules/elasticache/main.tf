# ElastiCache 서브넷 그룹 - 퍼블릭 서브넷 사용 (비용 절감, VPC 내부 접근만 허용)
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project}-redis-subnet"
  subnet_ids = var.subnet_ids
}

# Redis 클러스터 - 단일 노드 (개발/스테이징 환경)
# 프로덕션 전환 시 클러스터 모드 또는 Multi-AZ 복제 그룹으로 변경 고려
resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.project}-redis"
  engine               = "redis"
  node_type            = "cache.t3.medium"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.redis_sg_id]
}
