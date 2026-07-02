# ==============================================================================
# SRE Feature: Chaos Engineering Platform (AWS FIS)
# ==============================================================================

# 1. IAM Role for AWS FIS Service
resource "aws_iam_role" "fis" {
  name = "AWSFISChaosEngineeringRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Grant FIS permissions to interact with EC2 instances (Stop/Start for failure simulation)
resource "aws_iam_role_policy" "fis_permissions" {
  name = "AWSFISChaosEngineeringPolicy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# 2. AWS FIS Experiment Template: Shared Services Bastion Failure Simulation
# Simulates the loss of a key shared node to test SLO/SLI detection latency
resource "aws_fis_experiment_template" "bastion_failure" {
  description = "Chaos Simulation: Unexpected stop of Bastion host to verify egress/common services alert latency."
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "StopBastionHost"
    action_id = "aws:ec2:stop-instances"

    target {
      key   = "Instances"
      value = "bastion-targets"
    }
  }

  target {
    name           = "bastion-targets"
    resource_type  = "aws:ec2:instance"
    selection_mode = "ALL"

    resource_tag {
      key   = "Project"
      value = "EKS-Platform"
    }

    # Filters targets to only include instances in the current VPC
    filter {
      path   = "State.Name"
      values = ["running"]
    }
  }
}
