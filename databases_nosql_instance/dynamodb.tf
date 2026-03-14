resource "aws_dynamodb_table" "products" {
  name           = "${var.project_name}-${var.environment}-products"
  billing_mode   = "PROVISIONED"
  read_capacity  = 25
  write_capacity = 25
  hash_key       = "ProductID"
  range_key      = "Category"

  attribute {
    name = "ProductID"
    type = "S"
  }

  attribute {
    name = "Category"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-products"
    Environment = var.environment
    Project     = "databases-nosql-instance"
    ManagedBy   = "terraform"
  }
}
