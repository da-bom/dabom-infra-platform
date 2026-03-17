output "cluster_arn" {
  description = "MSK 클러스터 ARN"
  value       = aws_msk_cluster.this.arn
}

output "bootstrap_brokers" {
  description = "MSK 평문 부트스트랩 브로커 주소 - VPC 내부 통신"
  value       = aws_msk_cluster.this.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "MSK TLS 부트스트랩 브로커 주소"
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "zookeeper_connect_string" {
  description = "ZooKeeper 연결 문자열"
  value       = aws_msk_cluster.this.zookeeper_connect_string
}
