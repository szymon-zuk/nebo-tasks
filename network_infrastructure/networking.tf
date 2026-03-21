data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az0 = data.aws_availability_zones.available.names[0]
  az1 = data.aws_availability_zones.available.names[length(data.aws_availability_zones.available.names) > 1 ? 1 : 0]
}

resource "aws_subnet" "client" {
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, var.lab_subnet_netnum_start)
  availability_zone       = local.az0
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-client-subnet"
    Environment = var.environment
    Tier        = "public"
  }
}

resource "aws_subnet" "public_secondary" {
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, var.lab_subnet_netnum_start + 1)
  availability_zone       = local.az1
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-public-secondary-subnet"
    Environment = var.environment
    Tier        = "public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, var.lab_subnet_netnum_start + 2)
  availability_zone       = local.az0
  map_public_ip_on_launch = false

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-private-a-subnet"
    Environment = var.environment
    Tier        = "private"
  }
}

resource "aws_subnet" "private_server" {
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, var.lab_subnet_netnum_start + 3)
  availability_zone       = local.az1
  map_public_ip_on_launch = false

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-private-server-subnet"
    Environment = var.environment
    Tier        = "private"
  }
}

resource "aws_route_table" "lab_public" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.igw_id
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "lab_private" {
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab.id
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "client" {
  subnet_id      = aws_subnet.client.id
  route_table_id = aws_route_table.lab_public.id
}

resource "aws_route_table_association" "public_secondary" {
  subnet_id      = aws_subnet.public_secondary.id
  route_table_id = aws_route_table.lab_public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.lab_private.id
}

resource "aws_route_table_association" "private_server" {
  subnet_id      = aws_subnet.private_server.id
  route_table_id = aws_route_table.lab_private.id
}
