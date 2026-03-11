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
