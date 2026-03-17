variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "subnet_ids" {
  description = "ElastiCache 배포 서브넷 ID 목록"
  type        = list(string)
}

variable "redis_sg_id" {
  description = "Redis 보안그룹 ID"
  type        = string
}
