# MSK 커스텀 설정 - 프로덕션 최적화 파라미터
resource "aws_msk_configuration" "this" {
  name           = "${var.project}-msk-config"
  kafka_versions = ["3.6.0"]

  server_properties = <<-EOT
    # 토픽 자동 생성 - Producer가 메시지 전송 시 토픽이 없으면 자동 생성
    auto.create.topics.enable=true
    # 기본 복제 팩터 - 2개 브로커 환경
    default.replication.factor=2
    # 최소 동기화 복제본 - 데이터 내구성
    min.insync.replicas=1
    # 로그 보존 기간 7일
    log.retention.hours=168
  EOT
}

# MSK 클러스터 - 개발/스테이징용 소형 브로커 (t3.small)
resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.project}-msk"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type  = "kafka.t3.small"
    client_subnets = var.subnet_ids
    security_groups = [var.msk_sg_id]

    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }
  }

  # TLS_PLAINTEXT - VPC 내부 통신은 평문 허용, 외부 TLS
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }
}
