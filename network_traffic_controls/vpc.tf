# Use either an existing VPC (default) or create a dedicated lab VPC + IGW for a clean Resource map diagram.

data "aws_vpc" "selected" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id
}

resource "aws_vpc" "lab" {
  count                = var.create_vpc ? 1 : 0
  cidr_block           = var.new_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-vpc"
    Environment = var.environment
  }
}

data "aws_internet_gateway" "existing" {
  count = var.create_vpc ? 0 : 1
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_internet_gateway" "lab" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.lab[0].id

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-igw"
    Environment = var.environment
  }
}
