terraform {
  required_version = ">= 1.7.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # 모든 리소스에 공통 태그 적용 - 비용 추적 및 관리 용이성
  default_tags {
    tags = {
      Project     = "dabom"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

provider "cloudflare" {
  # CLOUDFLARE_API_TOKEN 환경변수로 인증
}

provider "random" {}
