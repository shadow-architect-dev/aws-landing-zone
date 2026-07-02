# ==============================================================================
# AWS Backup Governance Module
# ==============================================================================

# 1. AWS Backup Vault (Encrypted Storage)
resource "aws_backup_vault" "vault" {
  name        = "${var.environment}-backup-vault"
  kms_key_arn = var.kms_key_arn
}

# 2. AWS Backup Plan (Daily Schedule, 7 Days Retention)
resource "aws_backup_plan" "plan" {
  name = "${var.environment}-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.vault.name
    schedule          = "cron(0 5 * * ? *)" # Daily at 05:00 UTC (14:00 JST)

    lifecycle {
      delete_after = var.retention_days
    }
  }
}

# 3. IAM Role for AWS Backup Service
resource "aws_iam_role" "backup" {
  name = "${var.environment}-aws-backup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AWS Backup Policy to Role
resource "aws_iam_role_policy_attachment" "backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

# 4. Tag-based Backup Selection Guardrail
# Automatically backups any resource in this account with tag Backup = "true" or Backup = var.environment
resource "aws_backup_selection" "selection" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.environment}-backup-selection"
  plan_id      = aws_backup_plan.plan.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = var.environment
  }
}
