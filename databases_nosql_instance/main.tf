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
