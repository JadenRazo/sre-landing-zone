# IAM Identity Center — gated behind enable_identity_center_resources because
# the Identity Center INSTANCE itself can only be enabled via the console
# (one click in the management account, takes ~30 seconds). After that, run
# `terraform apply -var enable_identity_center_resources=true`.
#
# Console step: AWS Console → IAM Identity Center → Enable. Choose us-west-2
# as the home region.

data "aws_ssoadmin_instances" "main" {
  count = var.enable_identity_center_resources ? 1 : 0
}

locals {
  sso_instance_arn  = var.enable_identity_center_resources ? tolist(data.aws_ssoadmin_instances.main[0].arns)[0] : ""
  identity_store_id = var.enable_identity_center_resources ? tolist(data.aws_ssoadmin_instances.main[0].identity_store_ids)[0] : ""
}

# Permission sets — the canonical four for a small-team landing zone.
resource "aws_ssoadmin_permission_set" "admin" {
  count            = var.enable_identity_center_resources ? 1 : 0
  name             = "AdminAccess"
  description      = "Full administrative access. Use for break-glass and bootstrap; prefer PowerUser for daily work."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  count              = var.enable_identity_center_resources ? 1 : 0
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin[0].arn
}

resource "aws_ssoadmin_permission_set" "power_user" {
  count            = var.enable_identity_center_resources ? 1 : 0
  name             = "PowerUserAccess"
  description      = "Full access except IAM/Org management. Daily-driver permission set."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "power_user" {
  count              = var.enable_identity_center_resources ? 1 : 0
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  permission_set_arn = aws_ssoadmin_permission_set.power_user[0].arn
}

resource "aws_ssoadmin_permission_set" "read_only" {
  count            = var.enable_identity_center_resources ? 1 : 0
  name             = "ReadOnlyAccess"
  description      = "Read-only across the account. Use for reviews and demos."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "read_only" {
  count              = var.enable_identity_center_resources ? 1 : 0
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.read_only[0].arn
}

resource "aws_ssoadmin_permission_set" "billing" {
  count            = var.enable_identity_center_resources ? 1 : 0
  name             = "BillingOnly"
  description      = "Cost Explorer, Budgets, Billing. Use during cost reviews."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT2H"
}

resource "aws_ssoadmin_managed_policy_attachment" "billing" {
  count              = var.enable_identity_center_resources ? 1 : 0
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
  permission_set_arn = aws_ssoadmin_permission_set.billing[0].arn
}

# NOTE on assignments: aws_ssoadmin_account_assignment requires a principal
# (user or group) that lives in the Identity Store. Creating users via
# Terraform is possible but the very first user is best created in the console
# (you'll set their password and MFA there). After that, you can manage groups
# and assignments here. Documented in this stack's README.
