# ==============================================================================
# Terraform Backend Bootstrap Configuration (S3 & DynamoDB Table)
# ==============================================================================
#
# このコードは、最上位管理アカウント上で Terraform の状態管理用 S3 バケットおよび
# ステートロック用 DynamoDB テーブルを作成するための初期セットアップ（ブートストラップ）コードです。
# 初期実行時はローカルバックエンドで作成し、完了後にリモートへ移行します。

variable "region" {
  type        = string
  description = "AWS deployment region for backend resources"
  default     = "ap-northeast-1"
}

variable "management_account_id" {
  type        = string
  description = "AWS Management Account ID"
  default     = "111122223333"
}

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ------------------------------------------------------------------------------
# 1. KMS Key for S3 State Encryption
# ------------------------------------------------------------------------------

resource "aws_kms_key" "state_key" {
  description             = "KMS Key for encrypting Terraform remote state files"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "state_key_alias" {
  name          = "alias/landingzone-terraform-state-key"
  target_key_id = aws_kms_key.state_key.key_id
}

# ------------------------------------------------------------------------------
# 2. S3 State Bucket (With prevent_destroy enabled)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket        = "landingzone-terraform-state-${var.management_account_id}"
  force_destroy = false

  # 誤削除防止 (prevent_destroy) を有効化
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning (Enable versioning for state files retrieval)
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-KMS Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSL Connection Enforcement Policy
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_policy_doc.json
}

data "aws_iam_policy_document" "state_policy_doc" {
  statement {
    sid    = "EnforceSSLOnly"
    effect = "DENY"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ------------------------------------------------------------------------------
# 3. DynamoDB Table for State Locking
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "state_lock" {
  name         = "landingzone-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST" # オンデマンド (コスト最適)
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true # バックアップ有効化
  }
}
