output "core_ou_id" {
  value       = module.organizations.core_ou_id
  description = "Core Organizational Unit ID"
}

output "workloads_ou_id" {
  value       = module.organizations.workloads_ou_id
  description = "Workloads Organizational Unit ID"
}

output "log_archive_bucket_arn" {
  value       = module.log_archive.bucket_arn
  description = "Log Archive S3 Bucket ARN"
}

output "log_archive_firehose_arn" {
  value       = module.log_archive.firehose_arn
  description = "Log Archive Kinesis Firehose Stream ARN"
}

output "log_archive_delivery_role_arn" {
  value       = module.log_archive.delivery_role_arn
  description = "Cross-Account Logs Delivery IAM Role ARN"
}

output "cloudtrail_kms_key_arn" {
  value       = module.log_archive.kms_key_arn
  description = "CloudTrail KMS Key ARN"
}

output "github_deploy_role_arn" {
  value       = module.shared_services.github_deploy_role_arn
  description = "IAM Role ARN for GitHub Actions deployment"
}

# --- EKS 新規プロジェクト用パラメータ出力 ---

output "eks_dev_account_id" {
  value       = var.accounts.dev_eks
  description = "AWS Account ID for EKS Dev environment"
}

output "eks_dev_deploy_role_arn" {
  value       = module.eks_workload_baseline_dev.github_deploy_role_arn
  description = "GitHub Actions OIDC Deploy Role ARN for EKS Dev environment"
}

output "eks_stg_account_id" {
  value       = var.accounts.stg_eks
  description = "AWS Account ID for EKS Stg environment"
}

output "eks_stg_deploy_role_arn" {
  value       = module.eks_workload_baseline_stg.github_deploy_role_arn
  description = "GitHub Actions OIDC Deploy Role ARN for EKS Stg environment"
}

output "eks_prod_account_id" {
  value       = var.accounts.prod_eks
  description = "AWS Account ID for EKS Prod environment"
}

output "eks_prod_deploy_role_arn" {
  value       = module.eks_workload_baseline_prod.github_deploy_role_arn
  description = "GitHub Actions OIDC Deploy Role ARN for EKS Prod environment"
}

# --- Transit Gateway & IPAM Parameters ---

output "tgw_id" {
  value       = module.shared_services.tgw_id
  description = "Transit Gateway ID"
}

output "tgw_arn" {
  value       = module.shared_services.tgw_arn
  description = "Transit Gateway ARN"
}

output "ipam_pool_id" {
  value       = module.shared_services.ipam_pool_id
  description = "VPC IPAM Shared Parent Pool ID"
}
