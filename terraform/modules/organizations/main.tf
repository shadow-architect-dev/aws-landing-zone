# ==============================================================================
# AWS Organizations Module (Management Account)
# ==============================================================================

variable "root_id" { type = string }
variable "prod_account_id" { type = string }
variable "audit_account_id" { type = string }
variable "log_archive_account_id" { type = string }
variable "log_archive_bucket_arn" { type = string }
variable "log_archive_bucket_name" { type = string }
variable "cloudtrail_kms_key_arn" { type = string }
variable "dev_eks_account_id" { type = string }
variable "stg_eks_account_id" { type = string }
variable "prod_eks_account_id" { type = string }

# ------------------------------------------------------------------------------
# 1. Organizations structure (OUs & Accounts)
# ------------------------------------------------------------------------------

# Root Organization
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "ram.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com"
  ]
  feature_set = "ALL"
}

# AWS RAM の組織内自動承諾（自動共有）を有効化
resource "aws_ram_sharing_with_organization" "ram" {}

# Core OU
resource "aws_organizations_organizational_unit" "core" {
  name      = "Core"
  parent_id = var.root_id
}

# Workloads OU
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = var.root_id
}

# Nested OUs under Workloads for EKS projects
resource "aws_organizations_organizational_unit" "workloads_dev" {
  name      = "Development"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "workloads_stg" {
  name      = "Staging"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# Accounts declaration (to prevent deletion/drift and manage state imports)
resource "aws_organizations_account" "log_archive" {
  name      = "LogArchive"
  email     = "aws-root+logarchive@example.com"
  parent_id = aws_organizations_organizational_unit.core.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "audit" {
  name      = "Audit"
  email     = "aws-root+audit@example.com"
  parent_id = aws_organizations_organizational_unit.core.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "shared_services" {
  name      = "SharedServices"
  email     = "aws-root+sharedservices@example.com"
  parent_id = aws_organizations_organizational_unit.core.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "dev" {
  name      = "Dev"
  email     = "aws-root+dev@example.com"
  parent_id = aws_organizations_organizational_unit.workloads.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "stg" {
  name      = "Stg"
  email     = "aws-root+stg@example.com"
  parent_id = aws_organizations_organizational_unit.workloads.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "prod" {
  name      = "Prod"
  email     = "aws-root+prod@example.com"
  parent_id = aws_organizations_organizational_unit.workloads.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "dev_eks" {
  name      = "eks-three-tier-dev"
  email     = "aws-root+eks-dev@example.com"
  parent_id = aws_organizations_organizational_unit.workloads_dev.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "stg_eks" {
  name      = "eks-three-tier-stg"
  email     = "aws-root+eks-stg@example.com"
  parent_id = aws_organizations_organizational_unit.workloads_stg.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

resource "aws_organizations_account" "prod_eks" {
  name      = "eks-three-tier-prod"
  email     = "aws-root+eks-prod@example.com"
  parent_id = aws_organizations_organizational_unit.workloads_prod.id
  lifecycle { ignore_changes = [role_name, iam_user_access_to_billing] }
}

# ------------------------------------------------------------------------------
# 2. Service Control Policies (SCP)
# ------------------------------------------------------------------------------

# リージョン制限 SCP
resource "aws_organizations_policy" "restrict_regions" {
  name        = "RestrictRegionsToTokyo"
  description = "Restrict resource creation to ap-northeast-1 only."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../../../policies/scp/restrict-regions.json")
}

resource "aws_organizations_policy_attachment" "restrict_regions_core" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organizational_unit.core.id
}

resource "aws_organizations_policy_attachment" "restrict_regions_workloads" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# セキュリティサービス保護 SCP
resource "aws_organizations_policy" "protect_security_services" {
  name        = "ProtectSecurityServices"
  description = "Prevent disabling or deleting security services (CloudTrail, GuardDuty, SecurityHub, Config)."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../../../policies/scp/protect-security-services.json")
}

resource "aws_organizations_policy_attachment" "protect_security_core" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.core.id
}

resource "aws_organizations_policy_attachment" "protect_security_workloads" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# 本番データ削除防止 SCP
resource "aws_organizations_policy" "prevent_prod_deletion" {
  name        = "PreventProdDeletion"
  description = "Prevent deletion of critical data resources in production environment."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../../../policies/scp/prevent-prod-deletion.json")
}

resource "aws_organizations_policy_attachment" "prevent_prod_deletion_prod" {
  policy_id = aws_organizations_policy.prevent_prod_deletion.id
  target_id = var.prod_account_id
}

resource "aws_organizations_policy_attachment" "prevent_prod_deletion_prod_eks" {
  policy_id = aws_organizations_policy.prevent_prod_deletion.id
  target_id = var.prod_eks_account_id
}

# ------------------------------------------------------------------------------
# 3. Tag Policies
# ------------------------------------------------------------------------------

resource "aws_organizations_policy" "enforce_mandatory_tags" {
  name        = "EnforceMandatoryTags"
  description = "Enforce Environment and Project tags with standard values on workload resources."
  type        = "TAG_POLICY"
  content     = file("${path.module}/../../../policies/tag-policies/enforce-mandatory-tags.json")
}

resource "aws_organizations_policy_attachment" "enforce_tags_workloads" {
  policy_id = aws_organizations_policy.enforce_mandatory_tags.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# ------------------------------------------------------------------------------
# 4. Delegated Administrators (SecurityHub & GuardDuty)
# ------------------------------------------------------------------------------

resource "aws_organizations_delegated_administrator" "guardduty" {
  account_id        = var.audit_account_id
  service_principal = "guardduty.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "securityhub" {
  account_id        = var.audit_account_id
  service_principal = "securityhub.amazonaws.com"
}

# ------------------------------------------------------------------------------
# 5. Organization CloudTrail
# ------------------------------------------------------------------------------

resource "aws_cloudtrail" "org_trail" {
  name                          = "OrganizationTrail"
  s3_bucket_name                = var.log_archive_bucket_name
  kms_key_id                    = var.cloudtrail_kms_key_arn
  is_organization_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  enable_logging                = true

  # S3 bucket policy and KMS key permissions must allow CloudTrail before creating this
  depends_on = [
    var.log_archive_bucket_arn,
    var.cloudtrail_kms_key_arn
  ]
}

# ------------------------------------------------------------------------------
# 6. AWS Budgets
# ------------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly_budget" {
  name              = "OrganizationMonthlyBudget"
  budget_type       = "COST"
  limit_amount      = "1000"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-06-22_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["billing-alert@example.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["billing-alert@example.com"]
  }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "core_ou_id" {
  value = aws_organizations_organizational_unit.core.id
}

output "workloads_ou_id" {
  value = aws_organizations_organizational_unit.workloads.id
}
