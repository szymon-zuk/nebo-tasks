resource "aws_sns_topic" "lambda_alerts" {
  name = "${var.project_name}-${var.environment}-ebs-metrics-alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics-alerts"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-ebs-metrics-errors"
  alarm_description   = "Triggers when the EBS metrics Lambda function encounters errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.ebs_metrics.function_name
  }

  alarm_actions = [aws_sns_topic.lambda_alerts.arn]
  ok_actions    = [aws_sns_topic.lambda_alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics-errors"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-${var.environment}-ebs-metrics-duration"
  alarm_description   = "Triggers when Lambda duration approaches timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.lambda_timeout_s * 1000 * 0.8
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.ebs_metrics.function_name
  }

  alarm_actions = [aws_sns_topic.lambda_alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics-duration"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-${var.environment}-ebs-metrics-dlq"
  alarm_description   = "Triggers when messages arrive in the dead-letter queue"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.lambda_dlq.name
  }

  alarm_actions = [aws_sns_topic.lambda_alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics-dlq"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_dashboard" "serverless" {
  dashboard_name = "${var.project_name}-${var.environment}-ebs-metrics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Invocations & Errors"
          region = "eu-central-1"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.ebs_metrics.function_name, { stat = "Sum" }],
            [".", "Errors", ".", ".", { stat = "Sum", color = "#d62728" }],
            [".", "Throttles", ".", ".", { stat = "Sum", color = "#ff9900" }],
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration (ms)"
          region = "eu-central-1"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.ebs_metrics.function_name, { stat = "Average" }],
            ["...", { stat = "Maximum", color = "#d62728" }],
            ["...", { stat = "p90", color = "#ff9900" }],
          ]
          period = 300
          view   = "timeSeries"
          annotations = {
            horizontal = [
              {
                label = "Timeout Threshold (80%)"
                value = var.lambda_timeout_s * 1000 * 0.8
                color = "#d62728"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "EBS Unattached Volumes"
          region = "eu-central-1"
          metrics = [
            [var.metric_namespace, "UnattachedVolumes", { stat = "Maximum" }],
            [".", "UnattachedVolumesTotalSizeGiB", { stat = "Maximum", yAxis = "right" }],
          ]
          period = 300
          view   = "timeSeries"
          yAxis = {
            left  = { label = "Count" }
            right = { label = "GiB" }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "EBS Security Metrics"
          region = "eu-central-1"
          metrics = [
            [var.metric_namespace, "UnencryptedVolumes", { stat = "Maximum" }],
            [".", "UnencryptedSnapshots", { stat = "Maximum", color = "#d62728" }],
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Dead Letter Queue"
          region = "eu-central-1"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.lambda_dlq.name, { stat = "Maximum" }],
            [".", "NumberOfMessagesSent", ".", ".", { stat = "Sum", color = "#d62728" }],
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Concurrent Executions"
          region = "eu-central-1"
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", aws_lambda_function.ebs_metrics.function_name, { stat = "Maximum" }],
          ]
          period = 300
          view   = "timeSeries"
        }
      },
    ]
  })
}
