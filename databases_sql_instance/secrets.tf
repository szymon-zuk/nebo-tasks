resource "random_password" "master" {
  length  = 32
  special = true
  # Avoid characters that break URL/CLI quoting
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
  recovery_window_in_days = var.secret_recovery_window_days

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
  recovery_window_in_days = var.secret_recovery_window_days

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
