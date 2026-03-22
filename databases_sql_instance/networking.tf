# Default VPC keeps the lab small: no custom IGW/NAT/subnets to manage.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

locals {
  subnets_by_az = {
    for id, s in data.aws_subnet.default : s.availability_zone => id...
  }
  azs_sorted = sort(keys(local.subnets_by_az))
  # RDS subnet group needs two AZs in most regions.
  rds_subnet_ids = length(local.azs_sorted) >= 2 ? [
    local.subnets_by_az[local.azs_sorted[0]][0],
    local.subnets_by_az[local.azs_sorted[1]][0],
  ] : [local.subnets_by_az[local.azs_sorted[0]][0]]
}
