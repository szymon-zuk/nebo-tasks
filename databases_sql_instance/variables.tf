variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (e.g. dev)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "szzuk"
}

variable "rds_ingress_ipv4_cidr" {
  description = "IPv4 CIDR allowed to reach RDS on 5432. Default 0.0.0.0/0 for lab convenience; use e.g. 203.0.113.10/32 for stricter access."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition = (
      var.rds_ingress_ipv4_cidr != "" && (
        can(cidrhost(var.rds_ingress_ipv4_cidr, 0))
        || can(cidrhost("${var.rds_ingress_ipv4_cidr}/32", 0))
      )
    )
    error_message = "Use a valid IPv4 CIDR (e.g. 0.0.0.0/0 or 203.0.113.10/32) or a bare address (203.0.113.10)."
  }
}

variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "applab"
}

variable "master_username" {
  description = "RDS master username"
  type        = string
  default     = "dbadmin"
}

variable "app_username" {
  description = "Application username (bootstrap script creates this role in Postgres)"
  type        = string
  default     = "app_rw"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage (GiB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Max storage for autoscaling (0 disables)"
  type        = number
  default     = 50
}

variable "postgres_engine_version" {
  description = "PostgreSQL version for RDS"
  type        = string
  default     = "16.6"
}
