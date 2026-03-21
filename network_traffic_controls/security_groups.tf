locals {
  admin_ssh_cidr = var.enable_ssh && var.trusted_admin_cidr != "" ? [var.trusted_admin_cidr] : []
}

resource "aws_security_group" "client" {
  name        = "${local.aws_name_prefix}-netdemo-client-sg"
  description = "Client instance: least-privilege egress; optional SSH from trusted CIDR"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = local.admin_ssh_cidr
    content {
      description = "SSH from trusted admin CIDR only"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "HTTPS for SSM, patches, and AWS API traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Demo app ports to VPC (server private IP)"
    from_port   = min(var.demo_app_port_allow, var.demo_app_port_nacl_deny)
    to_port     = max(var.demo_app_port_allow, var.demo_app_port_nacl_deny)
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-client-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "server" {
  name        = "${local.aws_name_prefix}-netdemo-server-sg"
  description = "Server: app ports from client SG only; optional SSH from trusted CIDR"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = local.admin_ssh_cidr
    content {
      description = "SSH from trusted admin CIDR only"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description     = "Demo allowed port from client role only"
    from_port       = var.demo_app_port_allow
    to_port         = var.demo_app_port_allow
    protocol        = "tcp"
    security_groups = [aws_security_group.client.id]
  }

  ingress {
    description     = "Demo port blocked at NACL (SG allows for contrast)"
    from_port       = var.demo_app_port_nacl_deny
    to_port         = var.demo_app_port_nacl_deny
    protocol        = "tcp"
    security_groups = [aws_security_group.client.id]
  }

  egress {
    description = "HTTPS for SSM and updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-server-sg"
    Environment = var.environment
  }
}
