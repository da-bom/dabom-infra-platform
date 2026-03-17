# ECS 클러스터 - Fargate 전용, Container Insights 비활성화 (비용 절감)
resource "aws_ecs_cluster" "this" {
  name = "${var.project}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

# Fargate 용량 공급자 기본 전략 설정
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}
