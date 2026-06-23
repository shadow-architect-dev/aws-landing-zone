# ==============================================================================
# AWS Log Archive Module (Log Archive Account)
# ==============================================================================

variable "management_account_id" { type = string }
variable "dev_account_id" { type = string }
variable "stg_account_id" { type = string }
variable "prod_account_id" { type = string }

# Current region and account details
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# 1. KMS Key for Log Encryption
# ------------------------------------------------------------------------------

resource "aws_kms_key" "cloudtrail" {
  description             = "KMS Key for encrypting AWS CloudTrail logs in S3"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "cloudtrail_alias" {
  name          = "alias/cloudtrail-log-archive-key"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "cloudtrail_policy" {
  key_id = aws_kms_key.cloudtrail.id
  policy = data.aws_iam_policy_document.kms_policy_doc.json
}

data "aws_iam_policy_document" "kms_policy_doc" {
  # Default root access (required to prevent lockout)
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "ALLOW"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow CloudTrail to encrypt logs
  statement {
    sid    = "AllowCloudTrailEncrypt"
    effect = "ALLOW"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${var.management_account_id}:trail/*"]
    }
  }

  # Allow Kinesis Firehose and Fluent Bit Role to use the key
  statement {
    sid    = "AllowFirehoseDecryptEncrypt"
    effect = "ALLOW"
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.firehose_s3.arn,
        aws_iam_role.eks_fluent_bit_cross_account.arn
      ]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# 2. S3 Bucket for Log Archive
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "log_archive" {
  bucket        = "aws-landing-zone-log-archive-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = false
}

# SSE Encryption using KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cloudtrail.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "log_archive" {
  bucket                  = aws_s3_bucket.log_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSL Connection Enforcement & CloudTrail access S3 Policy
resource "aws_s3_bucket_policy" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  policy = data.aws_iam_policy_document.s3_policy_doc.json
}

data "aws_iam_policy_document" "s3_policy_doc" {
  # Enforce SSL/TLS connections
  statement {
    sid    = "EnforceSSLOnly"
    effect = "DENY"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.log_archive.arn,
      "${aws_s3_bucket.log_archive.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # CloudTrail ACL check
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "ALLOW"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.log_archive.arn]
  }

  # CloudTrail write logs
  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "ALLOW"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.log_archive.arn}/AWSLogs/*",
      "${aws_s3_bucket.log_archive.arn}/workloads/AWSLogs/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# ------------------------------------------------------------------------------
# 3. Kinesis Data Firehose (Delivery Stream) & Role
# ------------------------------------------------------------------------------

# Firehose Role to write to S3
resource "aws_iam_role" "firehose_s3" {
  name = "FirehoseToS3Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

# Firehose S3 + KMS Policy
resource "aws_iam_role_policy" "firehose_s3_policy" {
  name = "FirehoseToS3Policy"
  role = aws_iam_role.firehose_s3.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.log_archive.arn,
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.cloudtrail.arn
      }
    ]
  })
}

# Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "log_archive" {
  name        = "LogArchiveDeliveryStream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn    = aws_iam_role.firehose_s3.arn
    bucket_arn  = aws_s3_bucket.log_archive.arn
    kms_key_arn = aws_kms_key.cloudtrail.arn

    buffering_size      = 5
    buffering_interval  = 300
    compression_format  = "GZIP"
    prefix              = "workloads/"
    error_output_prefix = "errors/"
  }
}

# ------------------------------------------------------------------------------
# 4. Cross-Account Logs Delivery IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "cross_account_delivery" {
  name = "CrossAccountLogsDeliveryRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = [
              var.dev_account_id,
              var.stg_account_id,
              var.prod_account_id
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cross_account_delivery_policy" {
  name = "CrossAccountLogsDeliveryPolicy"
  role = aws_iam_role.cross_account_delivery.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Effect   = "Allow"
        Resource = aws_kinesis_firehose_delivery_stream.log_archive.arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 5. EKS Fluent Bit 直接送信用のクロスアカウント IAM ロール
# ------------------------------------------------------------------------------

resource "aws_iam_role" "eks_fluent_bit_cross_account" {
  name = "eks-fluent-bit-cross-account-role"

  # 送信元 (EKS Workloadアカウント) の Fluent Bit 用 IRSA ロールからの AssumeRole を信頼
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            # 各環境（Dev, Stg, Prod）の EKS アカウントの Fluent Bit ロールを信頼
            "arn:aws:iam::${var.dev_account_id}:role/eks-cluster-dev-fluent-bit-irsa",
            "arn:aws:iam::${var.stg_account_id}:role/eks-cluster-stg-fluent-bit-irsa",
            "arn:aws:iam::${var.prod_account_id}:role/eks-cluster-prod-fluent-bit-irsa"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 既存の Kinesis Data Firehose (LogArchiveDeliveryStream) への書き込み権限をアタッチ
resource "aws_iam_role_policy" "eks_fluent_bit_cross_account_policy" {
  name = "eks-fluent-bit-cross-account-policy"
  role = aws_iam_role.eks_fluent_bit_cross_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Effect   = "Allow"
        Resource = aws_kinesis_firehose_delivery_stream.log_archive.arn
      },
      # 暗号化されたストリームに書き込むためのKMSキー使用権限
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.cloudtrail.arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "bucket_arn" {
  value = aws_s3_bucket.log_archive.arn
}

output "bucket_name" {
  value = aws_s3_bucket.log_archive.id
}

output "kms_key_arn" {
  value = aws_kms_key.cloudtrail.arn
}

output "firehose_arn" {
  value = aws_kinesis_firehose_delivery_stream.log_archive.arn
}

output "delivery_role_arn" {
  value = aws_iam_role.cross_account_delivery.arn
}

output "eks_fluent_bit_delivery_role_arn" {
  value       = aws_iam_role.eks_fluent_bit_cross_account.arn
  description = "ARN of the cross-account IAM role for EKS Fluent Bit log delivery"
}
