# ==============================================================================
# AWS Shared Services Module (Management Account / GitHub Actions OIDC)
# ==============================================================================

variable "github_repo" { type = string }

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
# Outputs
# ------------------------------------------------------------------------------

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
