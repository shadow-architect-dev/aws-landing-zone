# ==============================================================================
# AWS Control Tower Account Factory Module (Management Account / Service Catalog)
# ==============================================================================

variable "control_tower" {
  type = object({
    productId              = string
    provisioningArtifactId = string
  })
}

# 1. accounts.yaml の読み込みとデコード (Terraform ネイティブ機能)
locals {
  accounts_yaml = file("${path.module}/../../accounts.yaml")
  accounts_data = yamldecode(local.accounts_yaml)
  accounts      = local.accounts_data.accounts
}

# 2. 各アカウント定義に基づいて Control Tower Account Factory 製品をプロビジョニング
resource "aws_servicecatalog_provisioned_product" "control_tower_account" {
  for_each = { for acc in local.accounts : acc.account_name => acc }

  name                     = each.value.account_name
  product_id               = var.control_tower.productId
  provisioning_artifact_id = var.control_tower.provisioningArtifactId

  # Control Tower Account Factory 用パラメータ
  provisioning_parameters {
    key   = "SSOUserEmail"
    value = "sso-admin@example.com"
  }

  provisioning_parameters {
    key   = "SSOUserFirstName"
    value = "SSO"
  }

  provisioning_parameters {
    key   = "SSOUserLastName"
    value = "Admin"
  }

  provisioning_parameters {
    key   = "AccountEmail"
    value = each.value.account_email
  }

  provisioning_parameters {
    key   = "AccountName"
    value = each.value.account_name
  }

  # 所属OUの自動解決
  provisioning_parameters {
    key   = "ManagedOrganizationalUnit"
    value = each.value.organizational_unit == "Core" ? "Core (ou-core-placeholder)" : "Workloads (ou-workloads-placeholder)"
  }
}
