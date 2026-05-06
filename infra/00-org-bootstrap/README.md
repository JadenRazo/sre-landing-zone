# Phase 0 — Multi-account foundation

Creates AWS Organizations, 4 member accounts, an OU layout, 4 SCPs, a Tag Policy, and (on a second apply) IAM Identity Center permission sets.

## What this creates

| Resource | Purpose | Reversibility |
|---|---|---|
| `aws_organizations_organization` | Turns the current account into an Org management account, ALL features enabled | One-way (you can leave the Org but it's annoying) |
| 3 OUs: Security, Workloads, Sandbox | Logical containers for SCPs | Reversible |
| 4 accounts: log-archive, audit-security, workloads-dev, workloads-prod | Workload separation + blast-radius isolation | **90-day cooldown** to fully close |
| 4 SCPs | Deny root, deny non-approved regions, require IMDSv2, deny disabling security | Reversible |
| 1 Tag Policy | Standards for Environment / Owner / CostCenter / Project | Reversible |
| SSM Parameter `/sre-landing-zone/account-map` | Lookup table for later phases | Reversible |

## Preflight

Run `../../scripts/preflight.sh` from the repo root first. Verify:
- Identity is the account that should become the management account
- Region is `us-west-2`
- Org is **not yet enabled** (this stack will enable it)

## Apply

```bash
# from this directory
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # set email_prefix and email_domain

terraform init
terraform plan -out=phase0.tfplan
# Review carefully. Look for: 4 aws_organizations_account creates, 4 SCP creates.
terraform apply phase0.tfplan
```

The first apply takes **5–7 minutes** — `aws_organizations_account` resources are slow because AWS is provisioning a real account behind each one. You'll see them go one at a time, not in parallel (Terraform serializes account creation by default to avoid throttling).

## After the first apply (one-time, console)

1. **Root user hardening** (if not already done):
   - Console → top-right user menu → My Security Credentials
   - Enable MFA (virtual or hardware key)
   - Delete any root access keys (your `sre-app-deploy` IAM user is the daily-driver)

2. **Enable IAM Identity Center**:
   - Console → IAM Identity Center → Enable
   - Choose `us-west-2` as the region (matches `home_region`)

3. **Create your Identity Center user**:
   - Identity Center → Users → Add user
   - Username: `jadenrazo`, email: your real email
   - Console emails a setup link; complete password + MFA

## Apply again (Identity Center resources)

```bash
terraform apply -var enable_identity_center_resources=true
```

This adds the 4 canonical permission sets: `AdminAccess`, `PowerUserAccess`, `ReadOnlyAccess`, `BillingOnly`.

## Verify

```bash
# Org exists and you're the management account
aws organizations describe-organization

# 5 accounts (mgmt + 4 created)
aws organizations list-accounts --query "Accounts[].[Id,Name,Status]" --output table

# 4 SCPs attached to the Workloads OU
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --query "Policies[].[Id,Name]" --output table

# SCP smoke test from a new account: this should be DENIED
aws sts assume-role --role-arn arn:aws:iam::<workloads-dev-id>:role/OrganizationAccountAccessRole --role-session-name test
# (then export the returned creds)
aws ec2 describe-instances --region eu-west-1   # should fail with explicit deny
aws ec2 describe-instances --region us-west-2   # should succeed (returns empty list)
```

## Rollback / teardown

**Don't.** Account closure has a 90-day cooldown, you can close at most 10% of your accounts in 30 days, and Org leave-and-rejoin re-creates the OrganizationAccountAccessRole differently. If you need to rebuild, prefer to:

1. `terraform destroy` everything except `aws_organizations_account` (remove those from state with `terraform state rm`)
2. Reuse the existing accounts in subsequent rebuilds

If you absolutely must close an account:
- Sign in to it as root (use the password reset flow from the email alias)
- Console → Account → Close Account
- Wait 90 days for full removal

## Cost

This stack: **$0/mo**. Organizations, OUs, SCPs, Tag Policies, Identity Center, and SSM Parameter Store (Standard tier, <10k requests/mo) are all free. The accounts themselves cost nothing until you put resources in them.

## Cross-cert mapping

- **CLF**: AWS Organizations, multi-account strategy, root user hygiene
- **SAA**: SCPs as preventive controls (Domain 1 — Secure), OU design, account-as-blast-radius pattern
- **CCSP**: Identity & access management (Domain 5), Cloud governance (Domain 1)
- **Cloud+**: Account hierarchy, governance, separation of duties
- **AZ-204 conceptual**: equivalent of Azure Management Groups + Azure Policy + Entra ID
