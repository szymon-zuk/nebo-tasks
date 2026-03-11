variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = "softserve-lab"
}

variable "aws_region" {
  description = "AWS region to build the AMI in"
  type        = string
  default     = "eu-central-1"
}

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

variable "instance_type" {
  description = "EC2 instance type used during the AMI build process"
  type        = string
  default     = "t2.micro"
}

variable "ami_description" {
  description = "Description for the resulting AMI"
  type        = string
  default     = "Custom Ubuntu 24.04 LTS AMI with nginx, stress-ng, CloudWatch agent, Vault, and Poetry"
}
