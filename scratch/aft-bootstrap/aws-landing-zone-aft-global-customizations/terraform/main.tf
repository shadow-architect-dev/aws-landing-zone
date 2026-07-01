# ==============================================================================
# AFT Global Customizations (Applied to ALL accounts)
# ==============================================================================

# 例：すべてのアカウントに共通で配置する最小限の IAM ロールやセキュリティアラート用定義などを記述します
resource "aws_iam_role" "aft_global_read_only" {
  name = "AFTGlobalReadOnlyRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = {
    ManagedBy = "AFT-Global-Customization"
  }
}

data "aws_caller_identity" "current" {}
