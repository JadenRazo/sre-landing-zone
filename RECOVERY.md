# Plan job recovery — three cancelled modules on PR #13

## Root cause (all three jobs, same reason)

`terraform plan` was missing `-input=false`. Terraform defaulted to interactive
mode and waited on stdin for two required variables that have no defaults:

| Module | Variable | Used for |
|---|---|---|
| `infra/00-org-bootstrap/` | `email_prefix` | Member account email aliases |
| `infra/01-security-baseline/` | `alert_email` | Budget / Security Hub SNS |
| `infra/06-cost-controls/` | `alert_email` | Cost Anomaly SNS + email sub |

`infra/02-workload-dev/`, `03-dr-pilot-light/`, `04-edge-and-data/`, `07-cicd/`,
`08-dns-delegation/`, and `_backend/` all give every variable a default, so they
never prompted and completed in ~24 seconds. This is a pre-existing workflow bug
unrelated to the v6 provider bump; the v6 bump just added those three modules to the
changed-phases list for the first time, exposing it.

## Code fix (already on this branch)

`plan.yml` now passes `-input=false` on `terraform plan` and injects the required
values as `TF_VAR_*` environment variables sourced from GitHub Actions Variables:

```yaml
env:
  TF_VAR_alert_email: ${{ vars.ALERT_EMAIL }}
  TF_VAR_email_prefix: ${{ vars.EMAIL_PREFIX }}
run: |
  terraform init -input=false
  terraform plan -input=false -no-color -out=tfplan 2>&1 | tee plan.txt
```

## Operational steps you must take before re-running the workflow

1. **Add two Actions Variables** in the repo (Settings → Secrets and variables →
   Actions → Variables tab — not Secrets, these values are non-sensitive):

   | Name | Value |
   |---|---|
   | `ALERT_EMAIL` | `jadenscottrazo@gmail.com` |
   | `EMAIL_PREFIX` | `jadenscottrazo` |

2. **Push this branch** and the PR will re-trigger `plan.yml` automatically, or
   trigger a re-run manually from the Actions tab on PR #13.

3. **Verify** that all three previously-cancelled jobs now complete within ~30 seconds
   (they reach AWS but plan against `-backend=false` state so there is nothing to
   actually read or write — runtime is dominated by provider init).

## Note on `infra/06-cost-controls/` specifically

This module also uses a `null_resource` + `local-exec` provisioner that shells out
to the AWS CLI to create a Tag Policy. Provisioners do not run during `terraform plan`
so this is not a plan-time hang vector — the hang was solely the missing `-input=false`.
At apply time, the `local-exec` will need the runner to have the `aws` CLI in PATH
(present on `ubuntu-latest`) and valid credentials (provided by the OIDC step).
