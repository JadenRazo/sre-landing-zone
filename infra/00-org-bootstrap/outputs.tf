output "organization_id" {
  description = "AWS Organizations ID (o-xxxxxxxxxx)."
  value       = aws_organizations_organization.main.id
}

output "management_account_id" {
  description = "Account ID of the management account (this account)."
  value       = data.aws_caller_identity.current.account_id
}

output "account_ids" {
  description = "Map of logical account name → account ID. Mirror of the SSM parameter."
  value = {
    management     = data.aws_caller_identity.current.account_id
    log_archive    = aws_organizations_account.log_archive.id
    audit_security = aws_organizations_account.audit_security.id
    workloads_dev  = aws_organizations_account.workloads_dev.id
    workloads_prod = aws_organizations_account.workloads_prod.id
  }
}

output "ou_ids" {
  description = "Map of OU name → OU ID. Used by later phases to attach additional policies."
  value = {
    security  = aws_organizations_organizational_unit.security.id
    workloads = aws_organizations_organizational_unit.workloads.id
    sandbox   = aws_organizations_organizational_unit.sandbox.id
  }
}

output "scp_ids" {
  description = "Map of SCP name → policy ID."
  value = {
    deny_root        = aws_organizations_policy.deny_root.id
    deny_regions     = aws_organizations_policy.deny_non_approved_regions.id
    require_imdsv2   = aws_organizations_policy.require_imdsv2.id
    deny_disable_sec = aws_organizations_policy.deny_disabling_security.id
  }
}

output "next_steps" {
  description = "What to do after this apply succeeds."
  value       = <<-EOT

    Phase 0 apply complete. Next:

    1. Set MFA on the root user (console → My Security Credentials).
       Then DELETE root access keys if any exist.

    2. Enable IAM Identity Center in the console (us-west-2):
       Console → IAM Identity Center → Enable.

    3. Create your first Identity Center USER in the console:
       Identity Center → Users → Add user (jadenrazo, your email).
       The console will email a one-time password setup link.

    4. Re-run Phase 0 apply with permission sets:
       terraform apply -var enable_identity_center_resources=true

    5. In the console, assign your user to the management account with
       the AdminAccess permission set. Verify SSO login works.

    6. Move to Phase 1: cd ../01-security-baseline (not yet implemented).
  EOT
}
