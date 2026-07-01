# AFT Global Customizations
# Place resources here that should be deployed to ALL AFT-provisioned AWS Accounts.
# Example: Default IAM Roles, SecurityHub enablement, config rules, or baseline logging.

resource "aws_securityhub_account" "this" {
  # Enable SecurityHub by default in all managed accounts
}
