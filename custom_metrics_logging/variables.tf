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

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}
