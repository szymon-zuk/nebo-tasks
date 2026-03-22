resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-pg-rds-sg"
  description = "PostgreSQL from trusted client CIDR only (TLS enforced on server)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL from your network (set trusted_client_cidr)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.trusted_client_cidr]
  }

  egress {
    description = "Unused for RDS; required by AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-pg-rds-sg"
    Environment = var.environment
  }
}
