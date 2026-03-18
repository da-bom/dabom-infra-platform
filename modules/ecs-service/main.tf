# CloudWatch 로그 그룹 - ECS 시스템 이벤트용 (1일 보존, 앱 로그는 OTLP로 전송)
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project}/${var.service_name}"
  retention_in_days = 1
}

# ECS 태스크 정의 - Fargate 전용, awsvpc 네트워크 모드
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      # 환경변수 - 민감하지 않은 설정값
      environment = var.environment_variables

      # 시크릿 - SSM Parameter Store에서 주입
      secrets = var.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# ECS 서비스 - Fargate 런치 타입, 조건부 ALB/서비스 디스커버리 연결
resource "aws_ecs_service" "this" {
  name            = "${var.project}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Spring Boot 기동 시간 동안 ALB health check 실패를 무시 (120초)
  health_check_grace_period_seconds = var.enable_load_balancer ? 120 : null

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  # ALB 연결 - enable_load_balancer=true 인 경우에만 생성
  dynamic "load_balancer" {
    for_each = var.enable_load_balancer && var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  # 서비스 디스커버리 - 서비스 간 내부 통신용 (dabom.local 네임스페이스)
  dynamic "service_registries" {
    for_each = var.service_discovery_arn != null ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }

  # desired_count만 ignore: 오토스케일링이 조정한 값을 Terraform이 되돌리지 않도록
  # task_definition은 ignore하지 않음: 환경변수 변경 시 자동 롤링 업데이트
  lifecycle {
    ignore_changes = [desired_count]
  }
}
