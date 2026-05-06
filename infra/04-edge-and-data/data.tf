data "aws_ssm_parameter" "account_map" {
  name = "/sre-landing-zone/account-map"
}

# Origin: Phase 2's ALB.
data "aws_lb" "origin" {
  provider = aws.workloads_dev
  name     = "sre-alb"
}

locals {
  accounts = jsondecode(data.aws_ssm_parameter.account_map.value)
}
