# bootstrap 레이어에서 VPC, 보안그룹, IAM 역할 등 기반 인프라 참조
data "terraform_remote_state" "bootstrap" {
  backend = "remote"
  config = {
    organization = var.tfc_organization
    workspaces = {
      name = "dabom-infra-bootstrap"
    }
  }
}

# AWS 계정 ID - SSM 파라미터 ARN 구성에 사용
data "aws_caller_identity" "current" {}

# 현재 리전 - ARN 구성에 사용
data "aws_region" "current" {}

locals {
  vpc_id                      = data.terraform_remote_state.bootstrap.outputs.vpc_id
  public_subnet_ids           = data.terraform_remote_state.bootstrap.outputs.public_subnet_ids
  alb_sg_id                   = data.terraform_remote_state.bootstrap.outputs.alb_sg_id
  ecs_sg_id                   = data.terraform_remote_state.bootstrap.outputs.ecs_sg_id
  rds_sg_id                   = data.terraform_remote_state.bootstrap.outputs.rds_sg_id
  redis_sg_id                 = data.terraform_remote_state.bootstrap.outputs.redis_sg_id
  msk_sg_id                   = data.terraform_remote_state.bootstrap.outputs.msk_sg_id
  ecs_task_execution_role_arn = data.terraform_remote_state.bootstrap.outputs.ecs_task_execution_role_arn
  ecs_task_role_arns          = data.terraform_remote_state.bootstrap.outputs.ecs_task_role_arns
  # ECR output 키가 "dabom/api-core" 형태이므로 "api-core"로 변환
  ecr_repository_urls = {
    for name, url in data.terraform_remote_state.bootstrap.outputs.ecr_repository_urls :
    trimprefix(name, "dabom/") => url
  }
}
