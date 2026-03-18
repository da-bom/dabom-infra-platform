# SSM 파라미터 ARN 맵 - ECS 태스크 시크릿 valueFrom에 사용
output "parameter_arns" {
  description = "SSM 파라미터 ARN 맵 - ECS 시크릿 참조용"
  value = {
    db_password      = aws_ssm_parameter.db_password.arn
    db_root_password = aws_ssm_parameter.db_root_password.arn
    jwt_secret_key   = aws_ssm_parameter.jwt_secret_key.arn
    r2_access_key    = aws_ssm_parameter.r2_access_key.arn
    r2_secret_key    = aws_ssm_parameter.r2_secret_key.arn
    vapid_private_key  = aws_ssm_parameter.vapid_private_key.arn
    slack_webhook_url  = aws_ssm_parameter.slack_webhook_url.arn
  }
}
