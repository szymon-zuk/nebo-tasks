output "rds_endpoint" {
  description = "RDS hostname (port 5432)"
  value       = aws_db_instance.main.address
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

output "master_secret_arn" {
  description = "Secrets Manager ARN for master credentials"
  value       = aws_secretsmanager_secret.master.arn
}

output "app_secret_arn" {
  description = "Secrets Manager ARN for application user credentials"
  value       = aws_secretsmanager_secret.app.arn
}
