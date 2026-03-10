output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ebs_metrics.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.ebs_metrics.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = aws_cloudwatch_event_rule.lambda_schedule.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge schedule rule"
  value       = aws_cloudwatch_event_rule.lambda_schedule.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "dlq_url" {
  description = "URL of the dead-letter queue"
  value       = aws_sqs_queue.lambda_dlq.url
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = aws_sns_topic.lambda_alerts.arn
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://eu-central-1.console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards:name=${aws_cloudwatch_dashboard.serverless.dashboard_name}"
}

output "invoke_command" {
  description = "AWS CLI command to manually invoke the function"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.ebs_metrics.function_name} --profile softserve-lab --region eu-central-1 --cli-binary-format raw-in-base64-out --payload '{}' /dev/stdout"
}

output "tail_logs_command" {
  description = "AWS CLI command to tail Lambda logs"
  value       = "aws logs tail ${aws_cloudwatch_log_group.lambda.name} --follow --profile softserve-lab --region eu-central-1"
}
