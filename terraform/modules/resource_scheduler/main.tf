# ==============================================================================
# AWS Resource Scheduler Module
# ==============================================================================

# 1. Package Python Lambda Code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/scheduler.py"
  output_path = "${path.module}/lambda_function.zip"
}

# 2. IAM Role for Lambda execution
resource "aws_iam_role" "lambda" {
  name = "${var.environment}-resource-scheduler-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for EC2 and RDS lifecycle control
#trivy:ignore:AVD-AWS-0057
resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${var.environment}-resource-scheduler-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "rds:DescribeDBInstances",
          "rds:StartDBInstance",
          "rds:StopDBInstance",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })
}

# 3. AWS Lambda Function definition
resource "aws_lambda_function" "scheduler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.environment}-resource-scheduler"
  role             = aws_iam_role.lambda.arn
  handler          = "scheduler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 300

  environment {
    variables = {
      SCHEDULE_TAG_VALUE = var.schedule_tag_value
    }
  }

  #trivy:ignore:AVD-AWS-0117
  tracing_config {
    mode = "PassThrough"
  }
}

# 4. EventBridge Schedule for Nightly Stop
resource "aws_cloudwatch_event_rule" "stop" {
  name                = "${var.environment}-resource-scheduler-stop-rule"
  description         = "Trigger stop of dev resources at 20:00 JST"
  schedule_expression = var.stop_cron
}

resource "aws_cloudwatch_event_target" "stop" {
  rule      = aws_cloudwatch_event_rule.stop.name
  target_id = "TriggerLambdaStop"
  arn       = aws_lambda_function.scheduler.arn
  input     = jsonencode({ action = "stop" })
}

# 5. EventBridge Schedule for Morning Start
resource "aws_cloudwatch_event_rule" "start" {
  name                = "${var.environment}-resource-scheduler-start-rule"
  description         = "Trigger start of dev resources at 08:00 JST"
  schedule_expression = var.start_cron
}

resource "aws_cloudwatch_event_target" "start" {
  rule      = aws_cloudwatch_event_rule.start.name
  target_id = "TriggerLambdaStart"
  arn       = aws_lambda_function.scheduler.arn
  input     = jsonencode({ action = "start" })
}

# 6. Lambda Permissions for EventBridge triggers
resource "aws_lambda_permission" "allow_eventbridge_stop" {
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop.arn
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start.arn
}
