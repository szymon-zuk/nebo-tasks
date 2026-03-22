output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB products table"
  value       = aws_dynamodb_table.products.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB products table"
  value       = aws_dynamodb_table.products.name
}

output "dynamodb_app_iam_user_name" {
  description = "IAM user for application-level access (CRUD/Query on this table and its GSIs only)"
  value       = aws_iam_user.dynamodb_app.name
}
