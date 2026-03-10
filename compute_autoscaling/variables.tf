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

variable "vpc_id" {
  description = "ID of the existing VPC to deploy into"
  type        = string
  default     = "vpc-05ad358b9f78248b0"
}

variable "instance_type" {
  description = "EC2 instance type for the launch template"
  type        = string
  default     = "t2.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for target tracking scaling policy"
  type        = number
  default     = 50.0
}

variable "scale_out_request_threshold" {
  description = "ALB request count per target threshold to trigger scale-out step policy"
  type        = number
  default     = 100
}

variable "scale_in_request_threshold" {
  description = "ALB request count per target threshold to trigger scale-in step policy"
  type        = number
  default     = 20
}

variable "business_hours_min_size" {
  description = "Minimum number of instances during business hours (scheduled scaling)"
  type        = number
  default     = 2
}

variable "cooldown_period" {
  description = "Cooldown period in seconds between scaling actions"
  type        = number
  default     = 300
}
