# EKS Workload Dev Account Customization
# Add workload-specific baselines here (e.g. specialized VPC subnets, peering, IAM policies)

locals {
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

# Example: Resource definition specifically for EKS workloads
resource "aws_ssm_parameter" "eks_env" {
  name  = "/config/eks/env_name"
  type  = "String"
  value = "development"
}
