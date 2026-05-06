data "aws_ssm_parameter" "account_map" {
  name = "/sre-landing-zone/account-map"
}

# Primary ALB lookup — Phase 2 creates this in workloads-dev us-west-2.
data "aws_lb" "primary" {
  provider = aws.workloads_dev_primary
  name     = "sre-alb"
}

# AZs in DR region.
data "aws_availability_zones" "dr_available" {
  provider = aws.workloads_dev_dr
  state    = "available"
}

locals {
  accounts = jsondecode(data.aws_ssm_parameter.account_map.value)

  dr_azs                 = slice(data.aws_availability_zones.dr_available.names, 0, 2)
  dr_public_subnet_cidrs = [for i in range(2) : cidrsubnet(var.dr_vpc_cidr, 8, i)] # 10.20.0.0/24, 10.20.1.0/24
}
