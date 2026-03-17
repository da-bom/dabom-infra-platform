# 서비스 디스커버리 - ECS 서비스 간 내부 통신용 DNS 네임스페이스
# dabom.local 도메인으로 서비스 검색 가능
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "dabom.local"
  vpc  = var.vpc_id
}

# 각 서비스별 서비스 디스커버리 레코드 생성
# 예: api-core.dabom.local, processor-usage.dabom.local 등
resource "aws_service_discovery_service" "this" {
  for_each = toset(var.service_names)

  name = each.value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      type = "A"
      ttl  = 10
    }

    # MULTIVALUE: 여러 태스크 IP 반환 (로드밸런싱 효과)
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
