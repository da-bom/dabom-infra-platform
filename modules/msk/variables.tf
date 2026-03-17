variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "subnet_ids" {
  description = "MSK 브로커 배포 서브넷 ID 목록"
  type        = list(string)
}

variable "msk_sg_id" {
  description = "MSK 보안그룹 ID"
  type        = string
}
