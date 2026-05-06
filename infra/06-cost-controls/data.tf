data "aws_ssm_parameter" "account_map" {
  name = "/sre-landing-zone/account-map"
}

data "aws_caller_identity" "management" {}

# Phase 1's SNS topic for budget alerts. We re-use it for cost anomaly subscriptions
# so the user doesn't get a second topic to subscribe to.
data "aws_sns_topic" "budget_alerts" {
  name = "sre-budget-alerts"
}

locals {
  accounts = jsondecode(data.aws_ssm_parameter.account_map.value)
}
