variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID - 프라이빗 DNS 네임스페이스 생성 위치"
  type        = string
}

variable "service_names" {
  description = "서비스 디스커버리 등록 서비스 이름 목록"
  type        = list(string)
  default     = ["api-core", "processor-usage", "api-notification", "batch-core"]
}
