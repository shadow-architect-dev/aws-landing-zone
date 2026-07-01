terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

# デフォルトのプロバイダー (管理アカウント向け)
provider "aws" {
  region = var.region
}

# 管理アカウント用 (明示的指定)
provider "aws" {
  alias  = "management"
  region = var.region
}

# Log Archive アカウント用プロバイダー
provider "aws" {
  alias  = "log_archive"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.logArchive}:role/OrganizationAccountAccessRole"
    session_name = "terraform-log-archive-session"
  }
}

# Audit / Security アカウント用プロバイダー
provider "aws" {
  alias  = "audit"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.audit}:role/OrganizationAccountAccessRole"
    session_name = "terraform-audit-session"
  }
}

# EKS Dev アカウント用プロバイダー
provider "aws" {
  alias  = "dev_eks"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.dev_eks}:role/OrganizationAccountAccessRole"
    session_name = "terraform-dev-eks-session"
  }
}

# EKS Stg アカウント用プロバイダー
provider "aws" {
  alias  = "stg_eks"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.stg_eks}:role/OrganizationAccountAccessRole"
    session_name = "terraform-stg-eks-session"
  }
}

# EKS Prod アカウント用プロバイダー
provider "aws" {
  alias  = "prod_eks"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.prod_eks}:role/OrganizationAccountAccessRole"
    session_name = "terraform-prod-eks-session"
  }
}

# App Dev アカウント用プロバイダー
provider "aws" {
  alias  = "dev"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-dev-session"
  }
}

# App Stg アカウント用プロバイダー
provider "aws" {
  alias  = "stg"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.stg}:role/OrganizationAccountAccessRole"
    session_name = "terraform-stg-session"
  }
}

# App Prod アカウント用プロバイダー
provider "aws" {
  alias  = "prod"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.prod}:role/OrganizationAccountAccessRole"
    session_name = "terraform-prod-session"
  }
}

# Shared Services アカウント用プロバイダー
provider "aws" {
  alias  = "shared_services"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.sharedServices}:role/OrganizationAccountAccessRole"
    session_name = "terraform-shared-services-session"
  }
}

# AFT Management アカウント用プロバイダー
provider "aws" {
  alias  = "aft_management"
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts.aft_management}:role/OrganizationAccountAccessRole"
    session_name = "terraform-aft-management-session"
  }
}
