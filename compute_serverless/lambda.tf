data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/src"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_lambda_function" "ebs_metrics" {
  function_name = "${var.project_name}-${var.environment}-ebs-metrics"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = var.lambda_timeout_s
  memory_size   = var.lambda_memory_mb
  description   = "Collects EBS volume/snapshot metrics and publishes to CloudWatch"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  reserved_concurrent_executions = 1

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  environment {
    variables = {
      CLOUDWATCH_NAMESPACE = var.metric_namespace
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-ebs-metrics"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-lambda-logs"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${var.project_name}-${var.environment}-ebs-metrics-dlq"
  message_retention_seconds = 1209600

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics-dlq"
    Environment = var.environment
  }
}
