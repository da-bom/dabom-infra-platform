# RDS 비밀번호 랜덤 생성 - lifecycle ignore_changes로 재생성 방지
resource "random_password" "rds" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}:?"
}

# RDS 서브넷 그룹
resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-rds-subnet"
  subnet_ids = var.subnet_ids
}

# MySQL 8.0 파라미터 그룹 - 한국어/이모지 지원 및 서울 타임존 설정
resource "aws_db_parameter_group" "this" {
  family = "mysql8.0"
  name   = "${var.project}-mysql8"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "time_zone"
    value = "Asia/Seoul"
  }

  # 커넥션 풀 고갈 방지 - ECS 서비스 최대 11태스크 × HikariCP 10 = 110 + 여유분
  parameter {
    name  = "max_connections"
    value = "150"
  }

  # ECS 태스크 강제 종료 시 반납되지 않은 좀비 커넥션 자동 정리
  # 기본값 28800초(8시간) → 300초(5분)로 단축
  parameter {
    name  = "wait_timeout"
    value = "300"
  }

  parameter {
    name  = "interactive_timeout"
    value = "300"
  }
}

# RDS MySQL 인스턴스 - db.t3.small (2GB RAM, max_connections ~166)
# 프로덕션 전환 시 multi_az=true, 더 큰 인스턴스 클래스 사용 권장
resource "aws_db_instance" "this" {
  identifier = "${var.project}-rds-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.small"

  allocated_storage     = 20
  storage_type          = "gp3"
  max_allocated_storage = 100

  db_name  = "app_db"
  username = "app_user"
  password = random_password.rds.result

  multi_az            = false
  publicly_accessible = true

  skip_final_snapshot     = true
  backup_retention_period = 1

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.this.name

  # 비밀번호는 SSM Parameter Store에서 관리, Terraform 상태 변경 무시
  lifecycle {
    ignore_changes = [password]
  }
}
