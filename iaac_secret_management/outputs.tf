# Outputs - safe to display information about created secrets and IAM roles/policies without exposing sensitive values

output "secret_arns" {
  description = "ARNs of created secrets"
  value = {
    db_password     = aws_secretsmanager_secret.db_password.arn
    api_key         = aws_secretsmanager_secret.api_key.arn
    ssh_private_key = aws_secretsmanager_secret.ssh_private_key.arn
    app_config      = aws_secretsmanager_secret.app_config.arn
  }
}

output "secret_names" {
  description = "Names of created secrets"
  value = {
    db_password     = aws_secretsmanager_secret.db_password.name
    api_key         = aws_secretsmanager_secret.api_key.name
    ssh_private_key = aws_secretsmanager_secret.ssh_private_key.name
    app_config      = aws_secretsmanager_secret.app_config.name
  }
}

output "iam_roles" {
  description = "IAM roles for secret access"
  value = {
    secrets_reader_role_arn  = aws_iam_role.secrets_reader.arn
    secrets_reader_role_name = aws_iam_role.secrets_reader.name
    secrets_admin_role_arn   = aws_iam_role.secrets_admin.arn
    secrets_admin_role_name  = aws_iam_role.secrets_admin.name
  }
}

output "iam_policies" {
  description = "IAM policies for secret access"
  value = {
    read_policy_arn  = aws_iam_policy.secrets_read_policy.arn
    admin_policy_arn = aws_iam_policy.secrets_admin_policy.arn
  }
}

output "aws_account_id" {
  description = "AWS Account ID where secrets are stored"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region where secrets are stored"
  value       = "eu-central-1"
}

# These outputs provide useful information for users to reference the created secrets and IAM roles/policies without exposing sensitive values. 
# They can be used in other Terraform configurations or for manual retrieval of secrets using AWS CLI.

output "db_password_retrieval_command" {
  description = "AWS CLI command to retrieve database password"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_password.name} --query SecretString --output text --profile softserve-lab --region eu-central-1"
}

output "api_key_retrieval_command" {
  description = "AWS CLI command to retrieve API key"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.api_key.name} --query SecretString --output text --profile softserve-lab --region eu-central-1"
}

output "ssh_public_key" {
  description = "SSH public key (safe to display)"
  value       = tls_private_key.ssh_key.public_key_openssh
}
