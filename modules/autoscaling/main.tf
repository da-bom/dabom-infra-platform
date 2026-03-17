# ECS 서비스 오토스케일링 - CPU 기반 타겟 트래킹
# batch 서비스는 제외 (이벤트 기반 실행, 스케일링 불필요)
resource "aws_appautoscaling_target" "this" {
  for_each = var.services

  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${var.cluster_name}/${var.cluster_name}-${each.key}"

  min_capacity = each.value.min
  max_capacity = each.value.max
}

# CPU 사용률 기반 타겟 트래킹 스케일링 정책
resource "aws_appautoscaling_policy" "cpu" {
  for_each = var.services

  name               = "${var.cluster_name}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = each.value.target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
