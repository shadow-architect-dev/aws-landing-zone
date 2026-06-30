# ==============================================================================
# AWS Shared Services Module (Management Account / GitHub Actions OIDC)
# ==============================================================================

variable "github_repo" { type = string }
variable "region" { type = string }
variable "accounts" {
  type = object({
    management     = string
    logArchive     = string
    audit          = string
    sharedServices = string
    dev            = string
    stg            = string
    prod           = string
    dev_eks        = string
    stg_eks        = string
    prod_eks       = string
  })
}

# ------------------------------------------------------------------------------
# 1. GitHub Actions 用の OIDC プロバイダーを作成
# ------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC Thumbprint
}

# ------------------------------------------------------------------------------
# 2. GitHub Actions デプロイ用 IAM ロール
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_deploy" {
  name                 = "GitHubActionsWorkflowDeployRole"
  description          = "Deployment role assumed by GitHub Actions for repository: ${var.github_repo}"
  max_session_duration = 7200 # 2時間

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# デプロイ用に管理者権限ポリシーを付与
resource "aws_iam_role_policy_attachment" "github_deploy_admin" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------------------
# 3. AWS Transit Gateway (TGW) & AWS RAM for Cross-Account Sharing
# ------------------------------------------------------------------------------

locals {
  spoke_accounts = [
    var.accounts.dev,
    var.accounts.stg,
    var.accounts.prod,
    var.accounts.dev_eks,
    var.accounts.stg_eks,
    var.accounts.prod_eks
  ]
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Landing Zone Shared Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "enable"

  tags = {
    Name = "landingzone-shared-tgw"
  }
}

# AWS RAM Resource Share
resource "aws_ram_resource_share" "tgw_share" {
  name                      = "transit-gateway-share"
  allow_external_principals = false
}

# Associate TGW with RAM
resource "aws_ram_resource_association" "tgw_association" {
  resource_arn       = aws_ec2_transit_gateway.tgw.arn
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

# Associate Spoke Accounts as Principals
resource "aws_ram_principal_association" "tgw_principals" {
  count              = length(local.spoke_accounts)
  principal          = local.spoke_accounts[count.index]
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "tgw_id" {
  value       = aws_ec2_transit_gateway.tgw.id
  description = "ID of the shared Transit Gateway"
}

output "tgw_arn" {
  value       = aws_ec2_transit_gateway.tgw.arn
  description = "ARN of the shared Transit Gateway"
}
