# SSM 파라미터 ARN 맵 - ECS 태스크 secrets valueFrom에 사용
output "parameter_arns" {
  description = "SSM 파라미터 ARN 맵 - ECS 시크릿 참조용"
  value = {
    # --- 공통 (전체 서비스) ---
    db_url                    = aws_ssm_parameter.db_url.arn
    db_name                   = aws_ssm_parameter.db_name.arn
    db_username               = aws_ssm_parameter.db_username.arn
    db_password               = aws_ssm_parameter.db_password.arn
    db_root_password          = aws_ssm_parameter.db_root_password.arn
    redis_host                = aws_ssm_parameter.redis_host.arn
    redis_port                = aws_ssm_parameter.redis_port.arn
    kafka_bootstrap_servers   = aws_ssm_parameter.kafka_bootstrap_servers.arn
    kafka_auto_offset_reset   = aws_ssm_parameter.kafka_auto_offset_reset.arn
    kafka_policy_dedup_ttl    = aws_ssm_parameter.kafka_policy_dedup_ttl.arn
    kafka_usage_persist_dedup_ttl = aws_ssm_parameter.kafka_usage_persist_dedup_ttl.arn
    frontend_url              = aws_ssm_parameter.cors_frontend_url.arn
    jwt_secret_key            = aws_ssm_parameter.jwt_secret_key.arn
    jwt_access_expires        = aws_ssm_parameter.jwt_access_expires.arn
    jwt_refresh_expires       = aws_ssm_parameter.jwt_refresh_expires.arn
    otel_sdk_disabled         = aws_ssm_parameter.otel_sdk_disabled.arn
    otel_endpoint             = aws_ssm_parameter.otel_endpoint.arn

    # --- 서비스별 Kafka Consumer Group ---
    kafka_group_id_api_core   = aws_ssm_parameter.kafka_group_id_api_core.arn
    kafka_group_id_proc_usage = aws_ssm_parameter.kafka_group_id_proc_usage.arn
    kafka_group_id_api_noti   = aws_ssm_parameter.kafka_group_id_api_noti.arn

    # --- api-core 전용 ---
    r2_endpoint               = aws_ssm_parameter.r2_endpoint.arn
    r2_access_key             = aws_ssm_parameter.r2_access_key.arn
    r2_secret_key             = aws_ssm_parameter.r2_secret_key.arn
    r2_bucket                 = aws_ssm_parameter.r2_bucket.arn
    r2_cdn_base_url           = aws_ssm_parameter.r2_cdn_base_url.arn

    # --- api-noti 전용 ---
    vapid_public_key          = aws_ssm_parameter.vapid_public_key.arn
    vapid_private_key         = aws_ssm_parameter.vapid_private_key.arn

    # --- batch-core 전용 ---
    slack_webhook_url         = aws_ssm_parameter.slack_webhook_url.arn
  }
}
