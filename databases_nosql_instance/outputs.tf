output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB products table"
  value       = aws_dynamodb_table.products.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB products table"
  value       = aws_dynamodb_table.products.name
}
