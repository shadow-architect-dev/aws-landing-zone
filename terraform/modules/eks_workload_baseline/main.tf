# ==============================================================================
# AWS EKS Workload Baseline Module (Applied to Dev/Stg/Prod EKS accounts)
# ==============================================================================

variable "github_eks_repo" {
  type        = string
  description = "GitHub repository for EKS project OIDC trust role"
}

variable "environment" {
  type        = string
  description = "Target environment name (dev, stg, prod)"
}

locals {
  # Guardrail 2: Restrict production deployment to main branch only
  github_sub_condition = var.environment == "prod" ? "repo:${var.github_eks_repo}:ref:refs/heads/main" : "repo:${var.github_eks_repo}:*"
}

# 1. GitHub Actions 用の OIDC プロバイダー
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC Thumbprint
}

# 2. GitHub Actions EKS デプロイ用 IAM ロール (GitHubActionsEKSDeployRole)
resource "aws_iam_role" "github_deploy" {
  name                 = "GitHubActionsEKSDeployRole"
  description          = "Deployment role assumed by GitHub Actions for EKS project: ${var.github_eks_repo}"
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
            "token.actions.githubusercontent.com:sub" = local.github_sub_condition
          }
        }
      }
    ]
  })
}

# EKS等のインフラ作成・デプロイ権限として管理者権限（AdministratorAccess）を付与
resource "aws_iam_role_policy_attachment" "github_deploy_admin" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "github_deploy_role_arn" {
  value       = aws_iam_role.github_deploy.arn
  description = "OIDC Deploy Role ARN"
}
