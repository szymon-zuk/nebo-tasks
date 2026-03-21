data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "client" {
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, var.lab_subnet_netnum_start)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-client-subnet"
    Environment = var.environment
  }
}

resource "aws_subnet" "server" {
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, var.lab_subnet_netnum_start + 1)
  availability_zone       = data.aws_availability_zones.available.names[length(data.aws_availability_zones.available.names) > 1 ? 1 : 0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-server-subnet"
    Environment = var.environment
  }
}

resource "aws_route_table" "lab_public" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.igw_id
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "client" {
  subnet_id      = aws_subnet.client.id
  route_table_id = aws_route_table.lab_public.id
}

resource "aws_route_table_association" "server" {
  subnet_id      = aws_subnet.server.id
  route_table_id = aws_route_table.lab_public.id
}
