# Pull the account map written by Phase 0. Avoids hardcoding IDs across the
# stack — if Phase 0 is rebuilt with different account IDs, this rehydrates.
data "aws_ssm_parameter" "account_map" {
  name = "/sre-landing-zone/account-map"
}

data "aws_caller_identity" "management" {}

data "aws_organizations_organization" "main" {}

locals {
  accounts = jsondecode(data.aws_ssm_parameter.account_map.value)

  # Convenience: list of all member account IDs (everything except management).
  member_account_ids = [
    local.accounts.log_archive,
    local.accounts.audit_security,
    local.accounts.workloads_dev,
    local.accounts.workloads_prod,
  ]
}
