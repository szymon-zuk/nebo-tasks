locals {
  aws_name_prefix = "szzuk-${var.environment}"

  vpc_id   = coalescelist(aws_vpc.lab[*].id, data.aws_vpc.selected[*].id)[0]
  vpc_cidr = coalescelist(aws_vpc.lab[*].cidr_block, data.aws_vpc.selected[*].cidr_block)[0]
  igw_id   = coalescelist(aws_internet_gateway.lab[*].id, data.aws_internet_gateway.existing[*].id)[0]
}

provider "aws" {
  profile = "softserve-lab"
  region  = "eu-central-1"

  default_tags {
    tags = {
      Owner       = "szzuk@softserveinc.com"
      Project     = "szzuk-network-infrastructure"
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
