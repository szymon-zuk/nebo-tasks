data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-${var.environment}-ebs-metrics-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ebs-metrics-role"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid = "DescribeEBS"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:DescribeVolumeStatus"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PutCustomMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [var.metric_namespace]
    }
  }

  statement {
    sid = "WriteLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.lambda.arn}:*"
    ]
  }

  statement {
    sid       = "SendToDLQ"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.lambda_dlq.arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.project_name}-${var.environment}-ebs-metrics-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}
