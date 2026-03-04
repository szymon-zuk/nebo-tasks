variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "szzuk"
}

variable "secret_recovery_window_days" {
  description = "Number of days AWS Secrets Manager waits before deleting a secret"
  type        = number
  default     = 7
}

variable "rotation_interval_days" {
  description = "Recommended number of days between manual secret rotations"
  type        = number
  default     = 30
}

variable "database_username" {
  description = "Database username (not sensitive)"
  type        = string
  default     = "admin"
}

variable "api_service_name" {
  description = "Name of the API service"
  type        = string
  default     = "external-api"
}
