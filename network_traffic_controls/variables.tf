variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "create_vpc" {
  description = "When true (default), create a new VPC and Internet Gateway (ignores vpc_id). Set false to attach the lab to an existing VPC via vpc_id."
  type        = bool
  default     = true
}

variable "new_vpc_cidr" {
  description = "IPv4 CIDR for the new VPC when create_vpc is true"
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrhost(var.new_vpc_cidr, 0))
    error_message = "new_vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "vpc_id" {
  description = "Existing VPC ID when create_vpc is false"
  type        = string
  default     = "vpc-05ad358b9f78248b0"

  validation {
    condition     = var.create_vpc || var.vpc_id != ""
    error_message = "When create_vpc is false, set vpc_id to your target VPC."
  }
}

variable "instance_type" {
  description = "EC2 instance type for client and server demo instances"
  type        = string
  default     = "t2.micro"
}

variable "trusted_admin_cidr" {
  description = "Trusted CIDR for optional SSH to lab instances (use /32 for your public IP). Unused when enable_ssh is false."
  type        = string
  default     = ""

  validation {
    condition     = var.trusted_admin_cidr == "" || can(cidrhost(var.trusted_admin_cidr, 0))
    error_message = "trusted_admin_cidr must be empty or a valid IPv4 CIDR."
  }
}

variable "enable_ssh" {
  description = "When true, security groups and NACLs allow SSH from trusted_admin_cidr only. Prefer false and use SSM."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_ssh || var.trusted_admin_cidr != ""
    error_message = "When enable_ssh is true, set trusted_admin_cidr (e.g. YOUR_PUBLIC_IP/32)."
  }
}

variable "lab_subnet_netnum_start" {
  description = "First index passed to cidrsubnet(..., 8, netnum) for lab subnets; increase if these /24s collide in your VPC"
  type        = number
  default     = 210
}

variable "demo_app_port_allow" {
  description = "TCP port the server listens on; permitted by SG and NACL (both layers)."
  type        = number
  default     = 8080

  validation {
    condition     = var.demo_app_port_allow >= 1 && var.demo_app_port_allow <= 65535
    error_message = "demo_app_port_allow must be between 1 and 65535."
  }
}

variable "demo_app_port_nacl_deny" {
  description = "TCP port open in SG but explicitly denied by server subnet NACL (defense-in-depth negative test)."
  type        = number
  default     = 9090

  validation {
    condition     = var.demo_app_port_nacl_deny >= 1 && var.demo_app_port_nacl_deny <= 65535 && var.demo_app_port_nacl_deny != var.demo_app_port_allow
    error_message = "demo_app_port_nacl_deny must be 1-65535 and different from demo_app_port_allow."
  }
}
