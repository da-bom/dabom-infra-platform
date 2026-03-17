variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "project" {
  description = "Project name prefix for ECS service names"
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
