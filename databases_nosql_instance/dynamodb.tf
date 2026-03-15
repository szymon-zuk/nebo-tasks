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

  attribute {
    name = "Price"
    type = "N"
  }

  global_secondary_index {
    name            = "PriceIndex"
    hash_key        = "Category"
    range_key       = "Price"
    projection_type = "ALL"
    read_capacity   = 25
    write_capacity  = 25
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-products"
    Environment = var.environment
    Project     = "databases-nosql-instance"
    ManagedBy   = "terraform"
  }
}
