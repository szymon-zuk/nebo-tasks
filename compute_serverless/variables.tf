variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "szzuk"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "lambda_memory_mb" {
  description = "Memory allocation for the Lambda function in MB"
  type        = number
  default     = 128
}

variable "lambda_timeout_s" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

variable "cron_expression" {
  description = "EventBridge schedule expression for Lambda trigger"
  type        = string
  default     = "cron(0 9 * * ? *)"
}

variable "metric_namespace" {
  description = "CloudWatch custom metrics namespace"
  type        = string
  default     = "ComputeServerless/EBSMetrics"
}
