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
      error_message = "Default VPC must have subnets in at least two availability zones for RDS. Restore or create a compliant default VPC."
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
  backup_retention_period      = var.backup_retention_period
  copy_tags_to_snapshot        = true
  deletion_protection          = false
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${local.name_prefix}-postgres-final"
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false

  tags = {
    Name        = "${local.name_prefix}-postgres"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
