# Security Hub: aggregates findings from GuardDuty, Config, IAM Access Analyzer,
# and the AWS-Foundational-Security-Best-Practices + CIS standards into a
# single posture-management dashboard.
#
# Cost: ~$0.0010 per finding ingested + ~$0.00003 per security check.
# CIS = ~150 checks/account × 2/day × $0.00003 ≈ $0.27/account/month.
# AFSBP = ~250 checks/account × 2/day × $0.00003 ≈ $0.45/account/month.
# At 4 active accounts: ~$3-5/month total. Worth it for the dashboard.
#
# Apply order (do not reorder casually):
#   1. Enable Security Hub in audit-security (the future delegated admin)
#   2. Delegate org admin from management to audit-security
#   3. Configure org-wide behavior (auto-enable, auto-standards)
#   4. Subscribe to standards

resource "aws_securityhub_account" "audit" {
  provider                  = aws.audit_security
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

resource "aws_securityhub_organization_admin_account" "delegate" {
  admin_account_id = local.accounts.audit_security
  depends_on       = [aws_securityhub_account.audit]
}

resource "aws_securityhub_organization_configuration" "audit" {
  provider              = aws.audit_security
  depends_on            = [aws_securityhub_organization_admin_account.delegate]
  auto_enable           = true
  auto_enable_standards = "DEFAULT"
}

resource "aws_securityhub_standards_subscription" "afsbp" {
  provider      = aws.audit_security
  depends_on    = [aws_securityhub_account.audit]
  standards_arn = "arn:aws:securityhub:${var.home_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  provider      = aws.audit_security
  depends_on    = [aws_securityhub_account.audit]
  standards_arn = "arn:aws:securityhub:${var.home_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}
