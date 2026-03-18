variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록 - ALB 배포 위치"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB 보안그룹 ID"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listeners"
  type        = string
}
