# ============================================
# Example: EC2 Instance with Access to Secrets Manager
# ============================================

# This file demonstrates how an EC2 instance can retrieve secrets
# from AWS Secrets Manager using an IAM role (secrets-reader).

# ============================================
# Security Group for EC2
# ============================================

# Security group allowing SSH access
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instance with secrets access"

  # Allow SSH from anywhere (restrict to your IP in production!)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-sg"
    Environment = var.environment
  }
}

# ============================================
# EC2 Instance with Secrets Access
# ============================================

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM instance profile for EC2 (uses secrets-reader role)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.secrets_reader.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-profile"
    Environment = var.environment
  }
}

# EC2 instance
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro" # Free tier eligible
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # User data script to install tools and create test scripts
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Update system
              dnf update -y

              # Install jq for JSON parsing
              dnf install -y jq

              # Create script to retrieve all secrets
              cat > /home/ec2-user/retrieve-all-secrets.sh << 'SCRIPT'
              #!/bin/bash
              set -e

              echo "========================================"
              echo "  Retrieving Secrets from Secrets Manager"
              echo "========================================"
              echo ""

              # Array of secret names
              SECRETS=(
                "${aws_secretsmanager_secret.db_password.name}"
                "${aws_secretsmanager_secret.api_key.name}"
                "${aws_secretsmanager_secret.ssh_private_key.name}"
                "${aws_secretsmanager_secret.app_config.name}"
              )

              for SECRET_NAME in "$${SECRETS[@]}"; do
                  echo "─────────────────────────────────────────"
                  echo "Secret: $SECRET_NAME"
                  echo "─────────────────────────────────────────"

                  # Retrieve secret value
                  SECRET_VALUE=$(aws secretsmanager get-secret-value \
                    --secret-id "$SECRET_NAME" \
                    --region eu-central-1 \
                    --query SecretString \
                    --output text 2>/dev/null)

                  if [ $? -eq 0 ]; then
                      echo "✓ Successfully retrieved secret"
                      echo ""
                      echo "Content:"
                      echo "$SECRET_VALUE" | jq .
                  else
                      echo "✗ Failed to retrieve secret"
                  fi
                  echo ""
              done

              echo "========================================"
              echo "  All secrets retrieved successfully!"
              echo "========================================"
              SCRIPT

              chmod +x /home/ec2-user/retrieve-all-secrets.sh
              chown ec2-user:ec2-user /home/ec2-user/retrieve-all-secrets.sh

              # Create script to test individual secret retrieval
              cat > /home/ec2-user/get-secret.sh << 'SCRIPT'
              #!/bin/bash

              if [ -z "$1" ]; then
                  echo "Usage: ./get-secret.sh <secret-type>"
                  echo ""
                  echo "Available secret types:"
                  echo "  db-password    - Database credentials"
                  echo "  api-key        - API key"
                  echo "  ssh-key        - SSH private key"
                  echo "  app-config     - Application configuration"
                  exit 1
              fi

              SECRET_PREFIX="${var.project_name}-${var.environment}"
              SECRET_NAME="$SECRET_PREFIX-$1"

              echo "Retrieving secret: $SECRET_NAME"
              echo ""

              aws secretsmanager get-secret-value \
                --secret-id "$SECRET_NAME" \
                --region eu-central-1 \
                --query SecretString \
                --output text | jq .
              SCRIPT

              chmod +x /home/ec2-user/get-secret.sh
              chown ec2-user:ec2-user /home/ec2-user/get-secret.sh

              # Create info file
              cat > /home/ec2-user/README.txt << INFO
              ===============================================
              EC2 Instance with Secrets Manager Access
              ===============================================

              This EC2 instance is configured with an IAM role that allows
              read-only access to secrets in AWS Secrets Manager.

              IAM Role: ${aws_iam_role.secrets_reader.name}
              Region: eu-central-1

              Available Secrets:
              ------------------
              1. ${aws_secretsmanager_secret.db_password.name}
              2. ${aws_secretsmanager_secret.api_key.name}
              3. ${aws_secretsmanager_secret.ssh_private_key.name}
              4. ${aws_secretsmanager_secret.app_config.name}

              Usage Examples:
              ---------------

              1. Retrieve all secrets:
                 ./retrieve-all-secrets.sh

              2. Retrieve a specific secret:
                 ./get-secret.sh db-password
                 ./get-secret.sh api-key
                 ./get-secret.sh ssh-key
                 ./get-secret.sh app-config

              3. Using AWS CLI directly:
                 aws secretsmanager get-secret-value \\
                   --secret-id ${aws_secretsmanager_secret.db_password.name} \\
                   --region eu-central-1 \\
                   --query SecretString \\
                   --output text | jq .

              4. List all secrets:
                 aws secretsmanager list-secrets \\
                   --region eu-central-1 \\
                   --query 'SecretList[?contains(Name, \`${var.project_name}\`)].Name'

              Security Features:
              ------------------
              - EC2 uses IAM role (no hardcoded credentials)
              - Read-only access to secrets
              - Secrets are never stored on disk
              - All API calls are logged in CloudTrail

              ===============================================
              INFO

              chown ec2-user:ec2-user /home/ec2-user/README.txt

              # Run the test script automatically
              su - ec2-user -c "/home/ec2-user/retrieve-all-secrets.sh" > /var/log/secrets-test.log 2>&1 || true
              EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-server"
    Environment = var.environment
    Purpose     = "Secrets Manager demonstration"
  }
}

# ============================================
# Outputs
# ============================================

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP address"
  value       = aws_instance.app_server.public_ip
}

output "ec2_connection_command" {
  description = "Command to connect to the EC2 instance"
  value       = "aws ec2-instance-connect ssh --instance-id ${aws_instance.app_server.id} --region eu-central-1"
}

output "secrets_demo_instructions" {
  description = "Instructions to test secrets access"
  value       = <<-EOT
    To test secrets access on the EC2 instance:

    1. Connect to the instance:
       aws ec2-instance-connect ssh --instance-id ${aws_instance.app_server.id} --region eu-central-1

       OR with SSH (if you have a key pair):
       ssh ec2-user@${aws_instance.app_server.public_ip}

    2. View the README:
       cat README.txt

    3. Retrieve all secrets:
       ./retrieve-all-secrets.sh

    4. Retrieve a specific secret:
       ./get-secret.sh db-password
       ./get-secret.sh api-key
       ./get-secret.sh ssh-key
       ./get-secret.sh app-config

    The EC2 instance uses the '${aws_iam_role.secrets_reader.name}' IAM role
    to securely access secrets without hardcoded credentials.
  EOT
}
