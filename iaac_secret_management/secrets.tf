# Database credentials for PostgreSQL

resource "random_password" "db_password" {
  length  = 32
  special = true
  # Avoid characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}-${var.environment}-db-password"
  description = "Database master password for ${var.environment} environment"

  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
    Type        = "database-credential"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.database_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = "db.example.com"
    port     = 5432
    dbname   = "${var.project_name}_${var.environment}"
  })
}

# API key

resource "random_password" "api_key" {
  length  = 64
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "aws_secretsmanager_secret" "api_key" {
  name        = "${var.project_name}-${var.environment}-api-key"
  description = "External API key for ${var.api_service_name} in ${var.environment}"

  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-key"
    Environment = var.environment
    Type        = "api-credential"
    Service     = var.api_service_name
  }
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
  secret_string = jsonencode({
    api_key = random_password.api_key.result
    service = var.api_service_name
  })
}

# SSH private key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "ssh_private_key" {
  name        = "${var.project_name}-${var.environment}-ssh-key"
  description = "SSH private key for server access in ${var.environment}"

  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssh-key"
    Environment = var.environment
    Type        = "ssh-credential"
  }
}

resource "aws_secretsmanager_secret_version" "ssh_private_key" {
  secret_id = aws_secretsmanager_secret.ssh_private_key.id
  secret_string = jsonencode({
    private_key = tls_private_key.ssh_key.private_key_pem
    public_key  = tls_private_key.ssh_key.public_key_openssh
    algorithm   = "RSA"
    key_size    = 4096
  })
}

# Application configuration secrets

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "random_password" "encryption_key" {
  length  = 64
  special = false
}

resource "random_password" "session_secret" {
  length  = 48
  special = true
}

resource "random_password" "webhook_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "app_config" {
  name        = "${var.project_name}-${var.environment}-app-config"
  description = "Application configuration secrets for ${var.environment}"

  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-config"
    Environment = var.environment
    Type        = "application-config"
  }
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    jwt_secret         = random_password.jwt_secret.result
    encryption_key     = base64encode(random_password.encryption_key.result)
    session_secret     = random_password.session_secret.result
    webhook_secret     = random_password.webhook_secret.result
    oauth_client_id    = "app-${var.environment}-client"
    oauth_redirect_uri = "https://${var.environment}.example.com/callback"
  })
}
