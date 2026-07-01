# ==============================================================================
# AFT Account Request Baseline
# ==============================================================================

module "eks_dev_account" {
  source = "github.com/aws-ia/terraform-aws-control_tower_account_factory//modules/aft-account-request"

  control_tower_parameters = {
    AccountEmail              = "aws-root+eks-dev-aft@example.com"
    AccountName               = "eks-three-tier-dev"
    ManagedOrganizationalUnit = "Development"
    SSOUserEmail              = "sso-admin@example.com"
    SSOUserFirstName          = "SSO"
    SSOUserLastName           = "Admin"
  }

  account_tags = {
    "Environment" = "dev"
    "Project"     = "eks-three-tier"
  }

  change_management_parameters = {
    change_requested_by = "SRE-Team"
    change_reason       = "Provisioning Development EKS Account via AFT"
  }

  custom_fields = {
    environment = "dev"
  }
}
