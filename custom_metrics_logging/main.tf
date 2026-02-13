provider "aws" {
  profile = "softserve-lab"
  region  = "eu-central-1"

  default_tags {
    tags = {
      Owner   = "szzuk@softserveinc.com"
      Project = "custom-metrics-logging"
    }
  }
}

variable "vpc_id" {
  description = "VPC ID where the ECS service runs"
  type        = string
  default     = "vpc-05ad358b9f78248b0"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS service (use public subnets if tasks need a public IP)"
  type        = list(string)
  default     = ["subnet-071840a9433d6a442"]
}

variable "container_image" {
  description = "Container image for the FastAPI app. Leave default (empty) to use the ECR repository created by this module (you must build and push the image to ECR first)."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}

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

resource "aws_ecs_cluster" "fastapi_cluster" {
  name = "custom-metrics-logging-cluster"
}

resource "aws_ecr_repository" "app" {
  name                 = "custom-metrics-logging"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/custom-metrics-logging"
  retention_in_days  = var.log_retention_days
}

# Re-use the existing ecsTaskExecutionRole (already in the account).
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}


resource "aws_ecs_task_definition" "fastapi_task" {
  family                   = "custom-metrics-logging-task"
  container_definitions    = jsonencode([
    {
      name      = "custom-metrics-logging-container"
      image     = var.container_image != "" ? var.container_image : "${aws_ecr_repository.app.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "fastapi_service" {
  name            = "fastapi-fargate-service"
  cluster         = aws_ecs_cluster.fastapi_cluster.id
  task_definition = aws_ecs_task_definition.fastapi_task.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }
}

# Dashboard for custom EMF metrics (namespace: CustomMetricsLogging/App)
resource "aws_cloudwatch_dashboard" "custom_metrics" {
  dashboard_name = "CustomMetricsLogging-App"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Request Count"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "RequestCount", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Sum" }],
            ["...", "Endpoint", "/Welcome", { stat = "Sum" }],
            ["...", "Endpoint", "/error", { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Request Latency (ms)"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "RequestLatencyMs", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Average" }],
            ["...", "Endpoint", "/Welcome", { stat = "Average" }],
            ["...", "Endpoint", "/error", { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Error Count"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "ErrorCount", "Service", "fastapi-custom-metrics", "Endpoint", "/error", { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Active Requests"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "ActiveRequests", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Maximum" }],
            ["...", "Endpoint", "/Welcome", { stat = "Maximum" }],
            ["...", "Endpoint", "/error", { stat = "Maximum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Endpoint Invocations"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "EndpointInvocations", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Sum" }],
            ["...", "Endpoint", "/Welcome", { stat = "Sum" }],
            ["...", "Endpoint", "/error", { stat = "Sum" }]
          ]
        }
      }
    ]
  })
}

# Alarm when ErrorCount (sum over 2 minutes) is >= 5
resource "aws_cloudwatch_metric_alarm" "high_error_count" {
  alarm_name          = "custom-metrics-logging-high-error-count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "CustomMetricsLogging/App"
  period              = 120
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Triggers when application error count (4xx/5xx) sum over 2 minutes is >= 5"

  dimensions = {
    Service  = "fastapi-custom-metrics"
    Endpoint = "/error"
  }
}

output "ecr_repository_url" {
  description = "ECR repository URL; use this to tag and push your image (e.g. <url>:latest)"
  value       = aws_ecr_repository.app.repository_url
}
