locals {
  # AWS console / API names use a fixed org resource prefix plus environment.
  aws_name_prefix = "szzuk-${var.environment}"
}

provider "aws" {
  profile = "softserve-lab"
  region  = "eu-central-1"

  default_tags {
    tags = {
      Owner       = "szzuk@softserveinc.com"
      Project     = "szzuk-network-traffic-controls"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
