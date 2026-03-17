variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "subnet_ids" {
  description = "RDS 배포 서브넷 ID 목록"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "RDS 보안그룹 ID"
  type        = string
}
