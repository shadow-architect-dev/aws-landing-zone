# ==============================================================================
# AWS Landing Zone Terraform Infrastructure Main Configuration
# ==============================================================================

# 1. Log Archive モジュール (Log Archive アカウントにデプロイ)
module "log_archive" {
  source = "./modules/log_archive"
  providers = {
    aws = aws.log_archive
  }

  management_account_id = var.accounts.management
  dev_account_id        = var.accounts.dev
  stg_account_id        = var.accounts.stg
  prod_account_id       = var.accounts.prod
}

# 2. Organizations モジュール (管理アカウントにデプロイ)
module "organizations" {
  source = "./modules/organizations"
  providers = {
    aws = aws.management
  }

  root_id                 = var.root_id
  prod_account_id         = var.accounts.prod
  audit_account_id        = var.accounts.audit
  log_archive_account_id  = var.accounts.logArchive
  log_archive_bucket_arn  = module.log_archive.bucket_arn
  log_archive_bucket_name = module.log_archive.bucket_name
  cloudtrail_kms_key_arn  = module.log_archive.kms_key_arn
  dev_eks_account_id      = var.accounts.dev_eks
  stg_eks_account_id      = var.accounts.stg_eks
  prod_eks_account_id     = var.accounts.prod_eks
}

# 3. Security Audit モジュール (Audit アカウントにデプロイ)
module "security_audit" {
  source = "./modules/security_audit"
  providers = {
    aws = aws.audit
  }
}

# 4. Identity モジュール (管理アカウントにデプロイ)
module "identity" {
  source = "./modules/identity"
  providers = {
    aws = aws.management
  }

  sso_instance_arn = var.sso_instance_arn
  accounts         = var.accounts
  sso_group_ids    = var.sso_group_ids
}

# 5. Shared Services モジュール (Shared Services アカウントにデプロイ)
module "shared_services" {
  source = "./modules/shared_services"
  providers = {
    aws = aws.shared_services
  }

  github_repo = var.github_repo
  accounts    = var.accounts
  region      = var.region
}

# 6. Account Factory モジュール (管理アカウントにデプロイ)
module "account_factory" {
  source = "./modules/account_factory"
  providers = {
    aws = aws.management
  }

  control_tower = var.control_tower
}

# 7. EKS 新規ワークロード用 OIDC / Deploy Role ベースラインモジュール

# 7-1. EKS Dev アカウント
module "eks_workload_baseline_dev" {
  source = "./modules/eks_workload_baseline"
  providers = {
    aws = aws.dev_eks
  }

  github_eks_repo = var.github_eks_repo
}

# 7-2. EKS Stg アカウント
module "eks_workload_baseline_stg" {
  source = "./modules/eks_workload_baseline"
  providers = {
    aws = aws.stg_eks
  }

  github_eks_repo = var.github_eks_repo
}

# 7-3. EKS Prod アカウント
module "eks_workload_baseline_prod" {
  source = "./modules/eks_workload_baseline"
  providers = {
    aws = aws.prod_eks
  }

  github_eks_repo = var.github_eks_repo
}

# ==============================================================================
# 8. Datadog AWS API Integration Configuration
# ==============================================================================

module "datadog_integration_management" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.management
  }
}

module "datadog_integration_log_archive" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.log_archive
  }
}

module "datadog_integration_audit" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.audit
  }
}

module "datadog_integration_dev" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.dev
  }
}

module "datadog_integration_stg" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.stg
  }
}

module "datadog_integration_prod" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.prod
  }
}

module "datadog_integration_dev_eks" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.dev_eks
  }
}

module "datadog_integration_stg_eks" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.stg_eks
  }
}

module "datadog_integration_prod_eks" {
  source              = "./modules/datadog_integration"
  datadog_external_id = var.datadog_external_id
  providers = {
    aws = aws.prod_eks
  }
}
