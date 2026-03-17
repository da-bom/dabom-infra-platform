variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "service_name" {
  description = "ECS 서비스 이름"
  type        = string
}

variable "cluster_id" {
  description = "ECS 클러스터 ID"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ECS 태스크 실행 역할 ARN - ECR, SSM, CloudWatch 접근"
  type        = string
}

variable "task_role_arn" {
  description = "ECS 태스크 역할 ARN - 애플리케이션 AWS 리소스 접근"
  type        = string
}

variable "cpu" {
  description = "Fargate CPU 단위 (256, 512, 1024, 2048, 4096)"
  type        = number
}

variable "memory" {
  description = "Fargate 메모리 MB"
  type        = number
}

variable "desired_count" {
  description = "원하는 태스크 수"
  type        = number
  default     = 1
}

variable "container_image" {
  description = "컨테이너 이미지 URI"
  type        = string
}

variable "container_port" {
  description = "컨테이너 포트"
  type        = number
  default     = 8080
}

variable "environment_variables" {
  description = "환경변수 목록"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "SSM Parameter Store 시크릿 목록"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "subnet_ids" {
  description = "ECS 태스크 배포 서브넷 ID 목록"
  type        = list(string)
}

variable "security_group_ids" {
  description = "ECS 태스크 보안그룹 ID 목록"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "퍼블릭 IP 할당 여부 - 퍼블릭 서브넷 사용 시 true"
  type        = bool
  default     = true
}

variable "enable_load_balancer" {
  description = "ALB 연결 여부"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ALB 타겟 그룹 ARN"
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "헬스체크 경로 - Spring Boot Actuator 사용"
  type        = string
  default     = "/actuator/health"
}

variable "service_discovery_arn" {
  description = "서비스 디스커버리 서비스 ARN - 서비스 간 내부 통신"
  type        = string
  default     = null
}
