# This file demonstrates how an EC2 instance can retrieve secrets
# from AWS Secrets Manager using an IAM role (secrets-reader).

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

# EC2 instance with secrets access

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

  user_data = <<-EOF
              #!/bin/bash
              set -e
              dnf update -y
              dnf install -y jq

              # Verify all secrets are accessible on boot (values not logged)
              SECRETS=(
                "${aws_secretsmanager_secret.db_password.name}"
                "${aws_secretsmanager_secret.api_key.name}"
                "${aws_secretsmanager_secret.ssh_private_key.name}"
                "${aws_secretsmanager_secret.app_config.name}"
              )
              for S in "$${SECRETS[@]}"; do
                aws secretsmanager get-secret-value \
                  --secret-id "$S" --region eu-central-1 \
                  --query 'Name' --output text
              done
              echo "All secrets verified" > /home/ec2-user/boot-status.txt
              chown ec2-user:ec2-user /home/ec2-user/boot-status.txt
              EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-server"
    Environment = var.environment
    Purpose     = "Secrets Manager demonstration"
  }
}

# Outputs

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
    1. Connect: aws ec2-instance-connect ssh --instance-id ${aws_instance.app_server.id} --region eu-central-1 --profile softserve-lab
    2. Verify boot check: cat boot-status.txt
    3. Retrieve a secret: aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_password.name} --region eu-central-1 --query SecretString --output text | jq .
  EOT
}
