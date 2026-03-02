resource "aws_security_group" "ecs_service" {
  name        = "custom-metrics-logging-ecs-sg"
  description = "Allow inbound HTTP (port 80) and all outbound for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "custom-metrics-logging-ecs-sg"
  }
}
