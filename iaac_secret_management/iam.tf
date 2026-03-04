# ============================================
# IAM Role for Secret Access - Read Only
# ============================================

resource "aws_iam_role" "secrets_reader" {
  name        = "${var.project_name}-${var.environment}-secrets-reader"
  description = "Role for applications to read secrets from Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "ec2.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets-reader"
    Environment = var.environment
    Purpose     = "Read-only access to secrets"
  }
}

# Policy for read-only access to secrets
resource "aws_iam_policy" "secrets_read_policy" {
  name        = "${var.project_name}-${var.environment}-secrets-read"
  description = "Allow reading secrets from Secrets Manager for ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.all_secret_arns
      },
      {
        Sid    = "ListSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "eu-central-1"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets-read"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "secrets_reader_attach" {
  role       = aws_iam_role.secrets_reader.name
  policy_arn = aws_iam_policy.secrets_read_policy.arn
}

# ============================================
# IAM Role for Secret Management - Admin
# ============================================

resource "aws_iam_role" "secrets_admin" {
  name        = "${var.project_name}-${var.environment}-secrets-admin"
  description = "Role for administrators to manage secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # In production, restrict this to specific IAM users or roles
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets-admin"
    Environment = var.environment
    Purpose     = "Full access to manage secrets"
  }
}

# Policy for full secret management
resource "aws_iam_policy" "secrets_admin_policy" {
  name        = "${var.project_name}-${var.environment}-secrets-admin"
  description = "Allow full management of secrets for ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = local.all_secret_arns
      },
      {
        Sid    = "ListAllSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets-admin"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "secrets_admin_attach" {
  role       = aws_iam_role.secrets_admin.name
  policy_arn = aws_iam_policy.secrets_admin_policy.arn
}

# ============================================
# Data source for current AWS account
# ============================================

data "aws_caller_identity" "current" {}

# ============================================
# Resource Policy for Secrets (Cross-Account Access Control)
# ============================================

locals {
  all_secret_arns = [
    aws_secretsmanager_secret.db_password.arn,
    aws_secretsmanager_secret.api_key.arn,
    aws_secretsmanager_secret.ssh_private_key.arn,
    aws_secretsmanager_secret.app_config.arn,
  ]

  all_secrets = {
    db_password     = aws_secretsmanager_secret.db_password.arn
    api_key         = aws_secretsmanager_secret.api_key.arn
    ssh_private_key = aws_secretsmanager_secret.ssh_private_key.arn
    app_config      = aws_secretsmanager_secret.app_config.arn
  }

  deny_external_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyExternalAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "secretsmanager:*"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_secretsmanager_secret_policy" "deny_external" {
  for_each   = local.all_secrets
  secret_arn = each.value
  policy     = local.deny_external_policy
}
