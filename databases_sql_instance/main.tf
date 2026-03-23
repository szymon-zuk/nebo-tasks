terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "aws" {
  profile = "softserve-lab"
  region  = var.aws_region

  default_tags {
    tags = {
      Owner   = "szzuk@softserveinc.com"
      Project = "databases-sql-instance"
    }
  }
}

# --- Default VPC (minimal lab: no custom IGW/NAT/subnets) ---

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  # Bare host (e.g. 203.0.113.10) → /32; full CIDRs unchanged
  rds_ingress_ipv4_cidr = can(cidrhost(var.rds_ingress_ipv4_cidr, 0)) ? var.rds_ingress_ipv4_cidr : "${var.rds_ingress_ipv4_cidr}/32"

  subnets_by_az = {
    for id, s in data.aws_subnet.default : s.availability_zone => id...
  }
  azs_sorted = sort(keys(local.subnets_by_az))
  rds_subnet_ids = length(local.azs_sorted) >= 2 ? [
    local.subnets_by_az[local.azs_sorted[0]][0],
    local.subnets_by_az[local.azs_sorted[1]][0],
  ] : [local.subnets_by_az[local.azs_sorted[0]][0]]

  # Lab defaults (override in code if you need stricter retention / final snapshot)
  backup_retention_period     = 1
  skip_final_snapshot         = true
  secret_recovery_window_days = 0
}

# --- Security group (name_prefix + create_before_destroy avoids ENI/SG destroy races) ---

resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-pg-rds-"
  description = "PostgreSQL 5432 from rds_ingress_ipv4_cidr (TLS enforced on RDS)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL (variable rds_ingress_ipv4_cidr; default 0.0.0.0/0 for lab)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.rds_ingress_ipv4_cidr]
  }

  egress {
    description = "Required by AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-pg-rds-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Secrets (passwords for master + app user; bootstrap script creates app role in Postgres) ---

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "app" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "master" {
  name                    = "${local.name_prefix}-rds-master"
  description             = "RDS master credentials for ${local.name_prefix}"
  recovery_window_in_days = local.secret_recovery_window_days

  tags = {
    Name        = "${local.name_prefix}-rds-master"
    Environment = var.environment
    Type        = "database-credential"
  }
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "postgres"
    port     = 5432
    dbname   = var.db_name
  })
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name_prefix}-rds-app"
  description             = "Application DB user credentials for ${local.name_prefix}"
  recovery_window_in_days = local.secret_recovery_window_days

  tags = {
    Name        = "${local.name_prefix}-rds-app"
    Environment = var.environment
    Type        = "database-credential"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    username = var.app_username
    password = random_password.app.result
    engine   = "postgres"
    port     = 5432
    dbname   = var.db_name
  })
}

# --- RDS ---

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-pg-subnets"
  subnet_ids = local.rds_subnet_ids

  tags = {
    Name        = "${local.name_prefix}-pg-subnets"
    Environment = var.environment
  }

  lifecycle {
    precondition {
      condition     = length(local.rds_subnet_ids) >= 2
      error_message = "Default VPC must have subnets in at least two availability zones for RDS."
    }
  }
}

resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-pg16"
  family      = "postgres16"
  description = "Force SSL for PostgreSQL lab"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name        = "${local.name_prefix}-pg-params"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  engine                = "postgres"
  engine_version        = var.postgres_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage > 0 ? var.db_max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  publicly_accessible          = true
  multi_az                     = false
  backup_retention_period      = local.backup_retention_period
  copy_tags_to_snapshot        = true
  deletion_protection          = false
  skip_final_snapshot          = local.skip_final_snapshot
  final_snapshot_identifier    = local.skip_final_snapshot ? null : "${local.name_prefix}-postgres-final"
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false

  tags = {
    Name        = "${local.name_prefix}-postgres"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
