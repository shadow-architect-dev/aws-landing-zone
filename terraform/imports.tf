# ==============================================================================
# AWS Landing Zone Terraform Import Declarations (Terraform 1.5+)
# ==============================================================================
#
# 既存の CDK でプロビジョニング済みのリソースを安全に Terraform State に取り込むための定義です。
# 実際の環境に合わせて ID (アカウントID、OUのID、KMSキーID等) を変更して実行してください。

# ------------------------------------------------------------------------------
# 1. AWS Organizations & Accounts
# ------------------------------------------------------------------------------

import {
  to = module.organizations.aws_organizations_organization.org
  id = "o-placeholder-org-id"
}

import {
  to = module.organizations.aws_organizations_organizational_unit.core
  id = "ou-core-placeholder-ou-id"
}

import {
  to = module.organizations.aws_organizations_organizational_unit.workloads
  id = "ou-workloads-placeholder-ou-id"
}

import {
  to = module.organizations.aws_organizations_account.log_archive
  id = "222222222222"
}

import {
  to = module.organizations.aws_organizations_account.audit
  id = "333333333333"
}

import {
  to = module.organizations.aws_organizations_account.shared_services
  id = "444444444444"
}

import {
  to = module.organizations.aws_organizations_account.dev
  id = "555555555555"
}

import {
  to = module.organizations.aws_organizations_account.stg
  id = "666666666666"
}

import {
  to = module.organizations.aws_organizations_account.prod
  id = "777777777777"
}

# ------------------------------------------------------------------------------
# 2. Service Control Policies (SCP) & Tag Policies
# ------------------------------------------------------------------------------

import {
  to = module.organizations.aws_organizations_policy.restrict_regions
  id = "p-restrict-regions-policy-id"
}

import {
  to = module.organizations.aws_organizations_policy.protect_security_services
  id = "p-protect-security-policy-id"
}

import {
  to = module.organizations.aws_organizations_policy.prevent_prod_deletion
  id = "p-prevent-prod-deletion-policy-id"
}

import {
  to = module.organizations.aws_organizations_policy.enforce_mandatory_tags
  id = "p-enforce-tags-policy-id"
}

# ------------------------------------------------------------------------------
# 3. Log Archive Account Resources (S3, KMS, Firehose, IAM)
# ------------------------------------------------------------------------------

import {
  to = module.log_archive.aws_kms_key.cloudtrail
  id = "arn:aws:kms:ap-northeast-1:222222222222:key/placeholder-kms-key-uuid"
}

import {
  to = module.log_archive.aws_kms_alias.cloudtrail_alias
  id = "arn:aws:kms:ap-northeast-1:222222222222:alias/cloudtrail-log-archive-key"
}

import {
  to = module.log_archive.aws_s3_bucket.log_archive
  id = "aws-landing-zone-log-archive-222222222222-ap-northeast-1"
}

import {
  to = module.log_archive.aws_iam_role.firehose_s3
  id = "FirehoseToS3Role-placeholder-suffix"
}

import {
  to = module.log_archive.aws_kinesis_firehose_delivery_stream.log_archive
  id = "arn:aws:firehose:ap-northeast-1:222222222222:deliverystream/LogArchiveDeliveryStream"
}

import {
  to = module.log_archive.aws_iam_role.cross_account_delivery
  id = "CrossAccountLogsDeliveryRole"
}

# ------------------------------------------------------------------------------
# 4. Security Audit Account Resources (Config, SecurityHub, GuardDuty)
# ------------------------------------------------------------------------------

import {
  to = module.security_audit.aws_config_configuration_aggregator.org
  id = "OrganizationConfigAggregator"
}

import {
  to = module.security_audit.aws_iam_role.config_aggregator
  id = "ConfigAggregatorRole-placeholder-suffix"
}

import {
  to = module.security_audit.aws_securityhub_account.audit
  id = "333333333333"
}

import {
  to = module.security_audit.aws_guardduty_detector.audit
  id = "placeholder-guardduty-detector-id"
}

# ------------------------------------------------------------------------------
# 5. Shared Services Resources (GitHub OIDC)
# ------------------------------------------------------------------------------

import {
  to = module.shared_services.aws_iam_openid_connect_provider.github
  id = "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
}

import {
  to = module.shared_services.aws_iam_role.github_deploy
  id = "GitHubActionsWorkflowDeployRole"
}

# ------------------------------------------------------------------------------
# 6. IAM Identity Center (SSO) Permission Sets
# ------------------------------------------------------------------------------

import {
  to = module.identity.aws_ssoadmin_permission_set.admin
  id = "arn:aws:sso:::permissionSet/ssoins-1111222233334444/ps-admin-placeholder"
}

import {
  to = module.identity.aws_ssoadmin_permission_set.power_user
  id = "arn:aws:sso:::permissionSet/ssoins-1111222233334444/ps-poweruser-placeholder"
}

import {
  to = module.identity.aws_ssoadmin_permission_set.read_only
  id = "arn:aws:sso:::permissionSet/ssoins-1111222233334444/ps-readonly-placeholder"
}
