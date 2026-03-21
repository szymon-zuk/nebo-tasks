# Stateless subnet-level filtering. Rule numbers: lower = evaluated first; first match wins.
# SG is stateful; NACL applies to every packet direction separately (ephemeral ports matter).

locals {
  admin_ssh_cidr_list = var.enable_ssh && var.trusted_admin_cidr != "" ? [var.trusted_admin_cidr] : []
}

resource "aws_network_acl" "client" {
  vpc_id     = local.vpc_id
  subnet_ids = [aws_subnet.client.id]

  dynamic "ingress" {
    for_each = local.admin_ssh_cidr_list
    content {
      protocol   = "tcp"
      rule_no    = 80
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 22
      to_port    = 22
    }
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = local.vpc_cidr
    from_port  = min(var.demo_app_port_allow, var.demo_app_port_nacl_deny)
    to_port    = max(var.demo_app_port_allow, var.demo_app_port_nacl_deny)
  }

  egress {
    protocol   = "udp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }

  egress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-client-nacl"
    Environment = var.environment
  }
}

resource "aws_network_acl" "server" {
  vpc_id     = local.vpc_id
  subnet_ids = [aws_subnet.server.id]

  dynamic "ingress" {
    for_each = local.admin_ssh_cidr_list
    content {
      protocol   = "tcp"
      rule_no    = 40
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 22
      to_port    = 22
    }
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = local.vpc_cidr
    from_port  = var.demo_app_port_allow
    to_port    = var.demo_app_port_allow
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = var.demo_app_port_nacl_deny
    to_port    = var.demo_app_port_nacl_deny
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = local.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "udp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-server-nacl"
    Environment = var.environment
  }
}
