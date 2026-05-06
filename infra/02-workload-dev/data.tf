data "aws_ssm_parameter" "account_map" {
  name = "/sre-landing-zone/account-map"
}

data "aws_availability_zones" "available" {
  provider = aws.workloads_dev
  state    = "available"
}

data "aws_caller_identity" "workloads_dev" {
  provider = aws.workloads_dev
}

locals {
  accounts             = jsondecode(data.aws_ssm_parameter.account_map.value)
  workloads_dev_id     = local.accounts.workloads_dev
  azs                  = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]      # 10.0.0.0/24, 10.0.1.0/24
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)] # 10.0.10.0/24, 10.0.11.0/24
}
