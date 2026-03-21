resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-nat-eip"
    Environment = var.environment
  }

  depends_on = [aws_route_table_association.client]
}

resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.client.id

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-nat-gw"
    Environment = var.environment
  }

  depends_on = [aws_route_table_association.client]
}
