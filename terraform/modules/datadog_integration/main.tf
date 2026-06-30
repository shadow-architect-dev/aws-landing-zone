# ==============================================================================
# Datadog AWS Integration Module
# ==============================================================================

variable "datadog_external_id" {
  type        = string
  description = "External ID provided by Datadog AWS Integration page"
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role for Datadog integration"
  default     = "DatadogIntegrationRole"
}

# 1. IAM Role for Datadog
resource "aws_iam_role" "datadog" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::464622532012:root" # Datadog AWS Account ID
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.datadog_external_id
          }
        }
      }
    ]
  })
}

# 2. Attach AWS Managed SecurityAudit Policy
resource "aws_iam_role_policy_attachment" "datadog_security_audit" {
  role       = aws_iam_role.datadog.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# 3. Attach Custom Additional Permissions required by Datadog
# Reference: https://docs.datadoghq.com/integrations/amazon_web_services/
resource "aws_iam_policy" "datadog_additional" {
  name        = "DatadogIntegrationAdditionalPolicy"
  description = "Additional permissions required by Datadog AWS Integration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "autoscaling:Describe*",
          "budgets:ViewBudget",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListDistributions",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "codedeploy:List*",
          "codedeploy:BatchGet*",
          "directconnect:Describe*",
          "dynamodb:List*",
          "dynamodb:Describe*",
          "ec2:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "elasticache:Describe*",
          "elasticache:List*",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeTags",
          "elasticloadbalancing:Describe*",
          "es:ListTags",
          "es:DescribeElasticsearchDomains",
          "firehose:ListDeliveryStreams",
          "firehose:DescribeDeliveryStream",
          "fsx:DescribeFileSystems",
          "fsx:ListTagsForResource",
          "kinesis:ListStreams",
          "kinesis:Describe*",
          "kinesis:ListTagsForStream",
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:TestMetricFilter",
          "logs:PutSubscriptionFilter",
          "organizations:Describe*",
          "organizations:List*",
          "rds:Describe*",
          "rds:List*",
          "redshift:DescribeClusters",
          "redshift:DescribeLoggingStatus",
          "route53:List*",
          "s3:GetBucketLogging",
          "s3:GetBucketLocation",
          "s3:GetBucketNotification",
          "s3:GetBucketTagging",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:PutBucketNotification",
          "sns:List*",
          "sns:Publish",
          "sqs:ListQueues",
          "states:ListStateMachines",
          "states:DescribeStateMachine",
          "support:*",
          "tag:GetResources",
          "tag:GetTagKeys",
          "tag:GetTagValues",
          "xray:BatchGetTraces",
          "xray:GetTraceSummaries"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "datadog_additional" {
  role       = aws_iam_role.datadog.name
  policy_arn = aws_iam_policy.datadog_additional.arn
}

output "role_arn" {
  value       = aws_iam_role.datadog.arn
  description = "ARN of the Datadog integration IAM role"
}
