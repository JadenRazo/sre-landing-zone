# Phase 1 — Centralized security & observability

Org-wide audit/security baseline. Reads the account map written by Phase 0 from SSM (`/sre-landing-zone/account-map`) and uses `OrganizationAccountAccessRole` (created automatically when Phase 0 made the accounts) to deploy resources into log-archive and audit-security accounts.

## What this creates

| Where | Resource | Purpose |
|---|---|---|
| log-archive | KMS CMK + alias | Encrypts the audit bucket; rotated yearly |
| log-archive | S3 bucket `sre-log-archive-<acct-id>` | Receives CloudTrail + Config logs |
| log-archive | Bucket policy + lifecycle | Deny insecure transport; tier to Glacier on age |
| management | CloudTrail org trail | Multi-region, all accounts, KMS-encrypted, log-validation on |
| audit-security (delegated) | GuardDuty detector + org config | Threat detection auto-enrolling all accounts |
| audit-security (delegated) | Security Hub + AFSBP + CIS standards | Posture management dashboard |
| management | Config recorder + delivery channel + 8 managed rules | Compliance evaluation in mgmt account |
| audit-security | Config aggregator | Single pane across the Org |
| management | SNS topic + email subscription | Channel for budget alerts |
| management | 2 AWS Budgets (forecast + actual) | $100 forecast at 20/50/80/100% + $20 hard-actual |

## Estimated cost

~$5–15/month at idle volumes:
- AWS Config: ~$2/month for the recorder + ~$0.001 per evaluation × ~8 rules × 4 evals/day ≈ $1
- GuardDuty: ~$1–2/month at idle (after 30-day free trial)
- Security Hub: ~$3/month for AFSBP+CIS at 4 accounts
- CloudTrail org trail: $0 (first copy is free for management events)
- S3 storage for logs: $0.023/GB; CloudTrail volume is small at idle (~10 MB/month)
- KMS: $1/month for the CMK
- Budgets: free (under 2 budgets)
- SNS: free (under 1k publishes/month)

If the bill exceeds $20 by end of week 2, audit. The biggest non-obvious risk: GuardDuty with S3 Protection or Malware Protection enabled — we explicitly disabled both.

## Preflight

```bash
# Phase 0 must be applied. This stack reads from its SSM parameter:
aws ssm get-parameter --name /sre-landing-zone/account-map

# Confirm you're in management account
aws sts get-caller-identity
```

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # set alert_email

terraform init
terraform plan -out=phase1.tfplan
# Review carefully. Expect ~25-30 resources to add.
terraform apply phase1.tfplan
```

**After apply**: AWS sends a "Confirm subscription" email to `alert_email` — click the link or budget alerts will silently fail.

## Verify

```bash
# Trail is shipping
aws cloudtrail describe-trails --query "trailList[?Name=='sre-org-trail']"
aws s3 ls s3://sre-log-archive-378356707832/AWSLogs/o-9itq8iim1q/ --recursive | head

# GuardDuty is on org-wide
aws guardduty list-organization-admin-accounts

# Security Hub aggregating
aws securityhub describe-hub --region us-west-2 --profile audit-security 2>&1 || \
  aws sts assume-role --role-arn arn:aws:iam::995303881355:role/OrganizationAccountAccessRole --role-session-name sh-check  # then use creds

# Config aggregator
aws configservice describe-configuration-aggregators --profile audit-security
```

## Smoke test (intentionally trip a finding)

In the management account console:

1. S3 → Create bucket `sre-test-public-please-delete`
2. Permissions → Block Public Access → uncheck Block public ACLs (Save)
3. Wait 30 minutes
4. Audit-security console → Security Hub → Findings — should see `S3.2` and/or `S3.3` failures
5. Delete the bucket

This proves CloudTrail captured the API call, Config flagged the resource, and Security Hub aggregated it.

## Cross-cert mapping

- **CLF**: shared responsibility model in action; CloudTrail / Config / GuardDuty awareness
- **SAA**: Secure (Domain 1, 30%) heaviest hits — encryption-at-rest with KMS, audit trail with CloudTrail, posture management
- **CCSP**: Domain 2 (Data Security), Domain 4 (Cloud App Security), Domain 5 (Cloud Sec Ops), Domain 6 (Legal/Risk/Compliance) — directly testable
- **Cloud+**: Logging, monitoring, governance, separation of duties via account boundaries
- **AZ-204 conceptual**: Defender for Cloud + Activity Log + Monitor + Sentinel = same shape
