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
  enable                        = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_organization_configuration" "audit" {
  auto_enable_organization_members = true
  detector_id                      = aws_guardduty_detector.audit.id
}

# ------------------------------------------------------------------------------
# 3. AWS Security Hub Configuration
# ------------------------------------------------------------------------------

resource "aws_securityhub_account" "audit" {
  enable_default_standards = true
}

resource "aws_securityhub_organization_configuration" "audit" {
  auto_enable = true
  depends_on  = [aws_securityhub_account.audit]
}
