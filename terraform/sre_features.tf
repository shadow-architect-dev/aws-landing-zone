# ==============================================================================
# Advanced SRE Features: Anomaly Detection & ChatOps (Slack)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Unified SRE Alerts SNS Topic
# ------------------------------------------------------------------------------
#trivy:ignore:AVD-AWS-0136
resource "aws_sns_topic" "sre_alerts" {
  name              = "sre-alerts-topic"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.sre_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    actions = ["SNS:Publish"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "costalerts.amazonaws.com"]
    }

    resources = [aws_sns_topic.sre_alerts.arn]
  }
}

# ------------------------------------------------------------------------------
# 2. AWS Cost Anomaly Detection Configuration
# ------------------------------------------------------------------------------
# ML-based monitor for unexpected cost surges
resource "aws_ce_anomaly_monitor" "service_monitor" {
  name              = "DailyServiceCostAnomalyMonitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "slack_subscription" {
  name             = "DailyCostAnomalySlackSubscription"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.service_monitor.arn]

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = [tostring(var.cost_anomaly_threshold)]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  subscriber {
    address = aws_sns_topic.sre_alerts.arn
    type    = "SNS"
  }
}

# ------------------------------------------------------------------------------
# 3. AWS Chatbot (Slack Channel Configuration)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "chatbot" {
  name = "AWSChatbotSlackAlertsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "chatbot_read_only" {
  role       = aws_iam_role.chatbot.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "chatbot_notifications" {
  role       = aws_iam_role.chatbot.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSChatbotServiceLinkedRolePolicy"
}

resource "aws_chatbot_slack_channel_configuration" "slack" {
  configuration_name = "sre-alerts-slack"
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_team_id

  sns_topic_arns = [
    aws_sns_topic.sre_alerts.arn
  ]
}
