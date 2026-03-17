output "endpoint" {
  description = "RDS 엔드포인트 (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS 호스트 주소"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS 포트"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "데이터베이스 이름"
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "데이터베이스 사용자 이름"
  value       = aws_db_instance.this.username
}

output "password" {
  description = "데이터베이스 비밀번호 (민감 정보)"
  value       = random_password.rds.result
  sensitive   = true
}
