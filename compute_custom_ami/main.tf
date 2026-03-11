provider "aws" {
  profile = "softserve-lab"
  region  = "eu-central-1"

  default_tags {
    tags = {
      Owner = "szzuk@softserveinc.com"
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

data "aws_ami" "custom" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Project"
    values = ["compute-custom-ami"]
  }

  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }

  filter {
    name   = "tag:ManagedBy"
    values = ["packer"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
