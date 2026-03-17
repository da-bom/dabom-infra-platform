variable "cluster_name" {
  description = "ECS 클러스터 이름 - 리소스 ID 구성에 사용"
  type        = string
}

variable "services" {
  description = "오토스케일링 대상 서비스 맵 - min, max, target_cpu 설정"
  type = map(object({
    min        = number
    max        = number
    target_cpu = number
  }))
}
