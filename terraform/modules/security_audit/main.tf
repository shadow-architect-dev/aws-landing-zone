# ==============================================================================
# AWS Security Audit Module (Audit Account)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. AWS Config Organization Aggregator
# ------------------------------------------------------------------------------

resource "aws_iam_role" "config_aggregator" {
  name = "ConfigAggregatorRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_aggregator_attachment" {
  role       = aws_iam_role.config_aggregator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "org" {
  name = "OrganizationConfigAggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator.arn
  }
}

# ------------------------------------------------------------------------------
# 2. Amazon GuardDuty Configuration
# ------------------------------------------------------------------------------

resource "aws_guardduty_detector" "audit" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_organization_configuration" "audit" {
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.audit.id
}

# ------------------------------------------------------------------------------
# 3. AWS Security Hub Configuration (Central Configuration Mode)
# ------------------------------------------------------------------------------

data "aws_region" "current" {}

resource "aws_securityhub_account" "audit" {
  enable_default_standards = false # Central configuration policy will manage standards
}

resource "aws_securityhub_organization_configuration" "audit" {
  auto_enable           = true
  auto_enable_standards = "NONE" # Central configuration policy will manage standards

  organization_configuration {
    configuration_type = "CENTRAL"
  }

  depends_on = [aws_securityhub_account.audit]
}

# 3.1 Non-Production Security Policy (Backup.1 Disabled to prevent costs/noise)
resource "aws_securityhub_configuration_policy" "non_prod" {
  name        = "NonProductionConfigurationPolicy"
  description = "Security Hub configuration policy for non-production environments with Backup.1 disabled."

  configuration_policy {
    service_enabled = true
    enabled_standard_arns = [
      "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
    ]

    security_controls_configuration {
      disabled_control_identifiers = [
        "Backup.1"
      ]
    }
  }

  depends_on = [aws_securityhub_organization_configuration.audit]
}

# 3.2 Production Security Policy (Backup.1 Enabled)
resource "aws_securityhub_configuration_policy" "prod" {
  name        = "ProductionConfigurationPolicy"
  description = "Security Hub configuration policy for production environments with Backup.1 enabled."

  configuration_policy {
    service_enabled = true
    enabled_standard_arns = [
      "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
    ]
  }

  depends_on = [aws_securityhub_organization_configuration.audit]
}

# 3.3 Associate Policy with Non-Prod Accounts
resource "aws_securityhub_configuration_policy_association" "dev" {
  target_id = var.accounts.dev
  policy_id = aws_securityhub_configuration_policy.non_prod.id
}

resource "aws_securityhub_configuration_policy_association" "stg" {
  target_id = var.accounts.stg
  policy_id = aws_securityhub_configuration_policy.non_prod.id
}

resource "aws_securityhub_configuration_policy_association" "dev_eks" {
  target_id = var.accounts.dev_eks
  policy_id = aws_securityhub_configuration_policy.non_prod.id
}

resource "aws_securityhub_configuration_policy_association" "stg_eks" {
  target_id = var.accounts.stg_eks
  policy_id = aws_securityhub_configuration_policy.non_prod.id
}

resource "aws_securityhub_configuration_policy_association" "shared_services" {
  target_id = var.accounts.sharedServices
  policy_id = aws_securityhub_configuration_policy.non_prod.id
}

# 3.4 Associate Policy with Prod Accounts
resource "aws_securityhub_configuration_policy_association" "prod" {
  target_id = var.accounts.prod
  policy_id = aws_securityhub_configuration_policy.prod.id
}

resource "aws_securityhub_configuration_policy_association" "prod_eks" {
  target_id = var.accounts.prod_eks
  policy_id = aws_securityhub_configuration_policy.prod.id
}

# ------------------------------------------------------------------------------
# 4. Organization Config Guardrails (Platform Level Security Governance)
# ------------------------------------------------------------------------------

# Guardrail 1: Check if ECS task definitions enforce non-root user execution
resource "aws_config_organization_managed_rule" "ecs_nonroot" {
  name            = "OrgEcsTaskNonRootUserCheck"
  rule_identifier = "ECS_TASK_DEFINITION_NONROOT_USER"
  description     = "Ensure ECS tasks are configured to run as a non-root user"
}

# Guardrail 3: Check if Security Groups restrict outbound (Egress) ports to prevent unrestricted outbound traffic
resource "aws_config_organization_managed_rule" "sg_egress_check" {
  name            = "OrgSecurityGroupEgressPortCheck"
  rule_identifier = "SECURITY_GROUP_EGRESS_PORT_LIMIT"
  description     = "Ensure security groups do not allow unrestricted outbound traffic"
}
