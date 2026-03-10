resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "${var.project_name}-${var.environment}-ebs-metrics-schedule"
  description         = "Scheduled trigger for EBS metrics collection"
  schedule_expression = var.cron_expression

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics-schedule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "EBSMetricsLambda"
  arn       = aws_lambda_function.ebs_metrics.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_metrics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}
