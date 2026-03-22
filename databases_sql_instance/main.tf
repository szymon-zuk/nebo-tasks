provider "aws" {
  profile = "softserve-lab"
  region  = var.aws_region

  default_tags {
    tags = {
      Owner   = "szzuk@softserveinc.com"
      Project = "databases-sql-instance"
    }
  }
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  # Accept either "x.x.x.x" or "x.x.x.x/32" in tfvars
  trusted_client_cidr = can(cidrhost(var.trusted_client_cidr, 0)) ? var.trusted_client_cidr : "${var.trusted_client_cidr}/32"
}
