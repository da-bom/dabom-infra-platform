# ALB API - 일반 REST API 트래픽용 (api-core 서비스)
resource "aws_lb" "api" {
  name               = "${var.project}-alb-api"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  # 일반 API 커넥션 타임아웃
  idle_timeout = 60

  enable_deletion_protection = false
}

# API 타겟 그룹 - api-core 서비스로 라우팅
resource "aws_lb_target_group" "api_core" {
  name        = "${var.project}-tg-api-core"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/actuator/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

# HTTP:80 리스너 - api-core 타겟 그룹으로 포워드
resource "aws_lb_listener" "api_http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_core.arn
  }
}

# ALB Noti - SSE(Server-Sent Events) 장시간 커넥션용 (api-notification 서비스)
resource "aws_lb" "noti" {
  name               = "${var.project}-alb-noti"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  # SSE 장기 연결 유지를 위해 타임아웃 연장
  idle_timeout = 300

  enable_deletion_protection = false
}

# Noti 타겟 그룹 - api-notification 서비스로 라우팅
resource "aws_lb_target_group" "api_noti" {
  name        = "${var.project}-tg-api-noti"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/actuator/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

# HTTP:80 리스너 - api-noti 타겟 그룹으로 포워드
resource "aws_lb_listener" "noti_http" {
  load_balancer_arn = aws_lb.noti.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_noti.arn
  }
}
