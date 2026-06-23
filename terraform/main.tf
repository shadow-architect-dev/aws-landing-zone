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

# 5. Shared Services モジュール (管理アカウントにデプロイ)
module "shared_services" {
  source = "./modules/shared_services"
  providers = {
    aws = aws.management
  }

  github_repo = var.github_repo
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
