variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

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

variable "trusted_client_cidr" {
  description = "Your public IPv4: bare address (203.0.113.10) or CIDR (203.0.113.10/32). Bare addresses are normalized to /32."
  type        = string

  validation {
    condition = (
      var.trusted_client_cidr != "" && (
        can(cidrhost(var.trusted_client_cidr, 0))
        || can(cidrhost("${var.trusted_client_cidr}/32", 0))
      )
    )
    error_message = "Set trusted_client_cidr to a valid IPv4 address (e.g. 203.0.113.10) or CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "applab"
}

variable "master_username" {
  description = "RDS master (admin) username"
  type        = string
  default     = "dbadmin"
}

variable "app_username" {
  description = "Application database username (created by bootstrap script)"
  type        = string
  default     = "app_rw"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling (0 disables autoscaling)"
  type        = number
  default     = 50
}

variable "postgres_engine_version" {
  description = "PostgreSQL major.minor version for RDS"
  type        = string
  default     = "16.6"
}

variable "backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "When true, destroy does not create a final DB snapshot (lab convenience)"
  type        = bool
  default     = true
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window on delete"
  type        = number
  default     = 0
}
