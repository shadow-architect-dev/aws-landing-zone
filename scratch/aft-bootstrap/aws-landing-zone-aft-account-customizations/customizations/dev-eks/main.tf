# ==============================================================================
# AFT Account Customizations (Applied specific to eks-three-tier-dev)
# ==============================================================================

# 例：EKS開発アカウント固有でデプロイしたい設定やVPCの動的タグなどを記述します
resource "aws_ssm_parameter" "aft_environment_label" {
  name  = "/aft/governance/environment"
  type  = "String"
  value = "development"

  tags = {
    ManagedBy = "AFT-Account-Customization"
  }
}
