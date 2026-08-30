# Remote-state backend bootstrap

Creates the S3 bucket + DynamoDB lock table that each phase can use as its Terraform backend. **The repository has no verified evidence that migration was completed.** Inventory AWS and every local state file before following this runbook.

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

The design uses small S3 state objects and DynamoDB on-demand billing, but this document makes no current-cost or free-tier guarantee.

## Migration runbook (for existing phases)

We scaffolded but **didn't migrate** the existing project's state because mid-project migration risks corruption if any apply runs against half-migrated state. To migrate when you have a planned maintenance window:

```bash
# 1. Inventory every local and remote state location, stop concurrent applies,
#    and copy each local state file to an encrypted backup outside the repo.

# 2. Apply this backend stack only after reviewing a saved plan.

# 3. For EACH existing phase (00 through 08), add the reviewed backend block,
#    then migrate one phase at a time:
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

# 4. Verify
terraform plan
# Expect: "No changes."

# 5. Keep the encrypted backup until a second operator or later session has
#    verified the remote object, versioning, lock behavior, and no-op plan.
```

Repeat for every phase directory. **Don't skip** the `terraform plan` verification step — if state migration corrupted anything, plan will show drift.

## Why the repository does not claim migration completion

The code alone cannot prove the current location or integrity of live state.
Recording completion without the remote object, version history, lock test, and
no-op plan would be false evidence. Treat the backend as a scaffold until those
checks are captured during an authorized maintenance window.

## Cross-cert mapping

- **SAA**: Cost-Optimized (PAY_PER_REQUEST DynamoDB), Resilient (S3 versioning + PITR off only because state lock isn't critical)
- **CCSP**: Domain 6 (governance) — versioned, encrypted state with audit trail via CloudTrail
- **AZ-204 conceptual**: Azure Storage container + Cosmos DB / Table Storage lock
