data "aws_caller_identity" "current" {}

# Enable AWS Organizations with all features. Idempotent if already enabled.
# `feature_set = "ALL"` is required for SCPs and consolidated billing.
resource "aws_organizations_organization" "main" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "ram.amazonaws.com",
    "ssm.amazonaws.com",
    "compute-optimizer.amazonaws.com",
    "access-analyzer.amazonaws.com",
  ]
}

# Organizational Units. SCPs attach to OUs (not root) so the management
# account itself is exempt from deny rules — preserves break-glass access.
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.main.roots[0].id
}

# Member accounts. Email must be unique across ALL of AWS globally — Gmail
# `+` aliasing satisfies this without buying domains. Account closure has a
# 90-day cooldown, so think before you `terraform destroy` here.
resource "aws_organizations_account" "log_archive" {
  name                       = "log-archive"
  email                      = "${var.email_prefix}+aws-log-archive@${var.email_domain}"
  parent_id                  = aws_organizations_organizational_unit.security.id
  iam_user_access_to_billing = "ALLOW"
  role_name                  = "OrganizationAccountAccessRole"

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "audit_security" {
  name                       = "audit-security"
  email                      = "${var.email_prefix}+aws-audit-security@${var.email_domain}"
  parent_id                  = aws_organizations_organizational_unit.security.id
  iam_user_access_to_billing = "ALLOW"
  role_name                  = "OrganizationAccountAccessRole"

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "workloads_dev" {
  name                       = "workloads-dev"
  email                      = "${var.email_prefix}+aws-workloads-dev@${var.email_domain}"
  parent_id                  = aws_organizations_organizational_unit.workloads.id
  iam_user_access_to_billing = "ALLOW"
  role_name                  = "OrganizationAccountAccessRole"

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "workloads_prod" {
  name                       = "workloads-prod"
  email                      = "${var.email_prefix}+aws-workloads-prod@${var.email_domain}"
  parent_id                  = aws_organizations_organizational_unit.workloads.id
  iam_user_access_to_billing = "ALLOW"
  role_name                  = "OrganizationAccountAccessRole"

  lifecycle {
    ignore_changes = [role_name]
  }
}

# Account map, written to SSM in the management account so later phases can
# look up account IDs by name without re-running this stack's outputs.
resource "aws_ssm_parameter" "account_map" {
  name        = "/sre-landing-zone/account-map"
  description = "Map of logical account name → account ID for cross-stack lookups."
  type        = "String"
  tier        = "Standard"
  value = jsonencode({
    management     = data.aws_caller_identity.current.account_id
    log_archive    = aws_organizations_account.log_archive.id
    audit_security = aws_organizations_account.audit_security.id
    workloads_dev  = aws_organizations_account.workloads_dev.id
    workloads_prod = aws_organizations_account.workloads_prod.id
  })
}

# Tag Policy intentionally deferred to Phase 6.
#
# We tried a minimal Tag Policy (Environment / Owner / CostCenter / Project) here
# and AWS returned MalformedPolicyDocumentException for reasons that didn't
# match the published schema. Rather than block Phase 0 on it, we defer:
#
# - All resources are still tagged via the provider `default_tags` block, so
#   cost attribution and visual identification work today.
# - In Phase 6, we'll author the Tag Policy via `aws organizations create-policy`
#   directly (skipping Terraform's wrapper), confirm AWS accepts it, then
#   import the result into Terraform state.
#
# This is a deliberate trade-off: getting Phase 0 unblocked is worth more than
# debugging an esoteric schema rejection right now.
