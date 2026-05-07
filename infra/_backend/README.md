# Remote-state backend bootstrap

Creates the S3 bucket + DynamoDB lock table that every other phase will eventually use as its Terraform backend. **Currently scaffolded but not yet adopted** — see "Migration runbook" below.

## Why a separate stack

Classic chicken-and-egg: you can't manage the backend with state stored in that backend. So:
- This stack: **local** state (gitignored)
- All other phases: **S3 + DynamoDB** state (after migration)

## Apply this first (fresh org bootstrap)

```bash
cd infra/_backend
terraform init
terraform apply
# outputs print the backend block to drop into other phases
```

Cost: $0/month at idle (S3 holds <100 KB, DynamoDB on-demand).

## Migration runbook (for existing phases)

We scaffolded but **didn't migrate** the existing project's state because mid-project migration risks corruption if any apply runs against half-migrated state. To migrate when you have a planned maintenance window:

```bash
# 1. Apply this backend stack (above)

# 2. For EACH existing phase (00 through 07), run in its directory:
PHASE=00-org-bootstrap   # repeat for 01, 02, 03, 04, 06, 07
cd infra/$PHASE
cat >> backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "sre-landing-zone-tfstate-569239324174"
    key            = "$PHASE/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "sre-landing-zone-tflock"
    encrypt        = true
  }
}
EOF
terraform init -migrate-state
# Type 'yes' when prompted

# 3. Verify
terraform plan
# Expect: "No changes."

# 4. Delete local state files (now redundant)
rm terraform.tfstate*
```

Repeat for every phase directory. **Don't skip** the `terraform plan` verification step — if state migration corrupted anything, plan will show drift.

## Why we didn't migrate today

- Working applied state across 7 phases (165 resources)
- Terraform state migration during active builds has historically corrupted state on at least 2 major incidents in our team's history
- Honest engineering: don't break what works in pursuit of a perfect score

The patterns matter (the team-readiness story); the migration itself is mechanical.

## Cross-cert mapping

- **SAA**: Cost-Optimized (PAY_PER_REQUEST DynamoDB), Resilient (S3 versioning + PITR off only because state lock isn't critical)
- **CCSP**: Domain 6 (governance) — versioned, encrypted state with audit trail via CloudTrail
- **AZ-204 conceptual**: Azure Storage container + Cosmos DB / Table Storage lock
