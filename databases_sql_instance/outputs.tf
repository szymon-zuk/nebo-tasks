output "vpc_id" {
  description = "Default VPC ID where RDS runs"
  value       = data.aws_vpc.default.id
}

output "rds_endpoint" {
  description = "RDS hostname (no port)"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_name" {
  description = "Application database name"
  value       = var.db_name
}

output "master_secret_arn" {
  description = "Secrets Manager ARN for master (admin) credentials"
  value       = aws_secretsmanager_secret.master.arn
}

output "app_secret_arn" {
  description = "Secrets Manager ARN for application user credentials"
  value       = aws_secretsmanager_secret.app.arn
}

output "aws_region" {
  description = "Region where resources were created"
  value       = var.aws_region
}
