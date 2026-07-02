# ==============================================================================
# SRE Feature: Security & Infrastructure Drift Detection
# ==============================================================================

# 1. AWS Config Rule: Restricted Common Ports Audit
# Check if Security Groups allow unrestricted incoming traffic to common ports (SSH/RDP)
resource "aws_config_config_rule" "restricted_ports" {
  name        = "RestrictedCommonPortsDriftCheck"
  description = "Checks whether security groups allow unrestricted incoming traffic to authorized common ports (22, 3389)."

  source {
    owner             = "AWS"
    source_identifier = "RESTRICTED_COMMON_PORTS"
  }

  input_parameters = jsonencode({
    blockedGateways = ["0.0.0.0/0"]
  })
}

# 2. EventBridge Rule: Detect Non-Compliant Config Rules (Drift)
# Fires when any AWS Config rule status changes to NON_COMPLIANT
resource "aws_cloudwatch_event_rule" "config_drift" {
  name        = "aws-config-compliance-drift-rule"
  description = "Triggers when an AWS Config rule reports a resources as NON_COMPLIANT (Drift detected)."

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

# 3. EventBridge Target: Forward Drift Events to Unified Slack SNS Topic
resource "aws_cloudwatch_event_target" "sns_drift_target" {
  rule      = aws_cloudwatch_event_rule.config_drift.name
  target_id = "SendDriftToSnsTopic"
  arn       = var.sns_topic_arn
}
