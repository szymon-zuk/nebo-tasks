provider "aws" {
  profile = "softserve-lab"
  region  = "eu-central-1"

  default_tags {
    tags = {
      Owner   = "szzuk@softserveinc.com"
      Project = "custom-metrics-logging"
    }
  }
}
