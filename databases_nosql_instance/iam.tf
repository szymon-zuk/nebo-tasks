resource "aws_iam_user" "dynamodb_app" {
  name = "${var.project_name}-${var.environment}-dynamodb-app"
  tags = {
    Project     = "databases-nosql-instance"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_user_policy" "dynamodb_app" {
  name = "${var.project_name}-${var.environment}-dynamodb-app-table"
  user = aws_iam_user.dynamodb_app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBTableAndGsi"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable",
        ]
        Resource = [
          aws_dynamodb_table.products.arn,
          "${aws_dynamodb_table.products.arn}/index/*",
        ]
      },
    ]
  })
}
