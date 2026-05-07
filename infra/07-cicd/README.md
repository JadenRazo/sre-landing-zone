# Phase 7 — CI/CD: GitHub Actions OIDC

Adds the AWS IAM trust setup that lets `.github/workflows/*.yml` run Terraform plan/apply against this org without long-lived credentials. **No AWS access keys exist anywhere** — every workflow run gets a ~1-hour STS session via OIDC.

## What this creates

| Resource | Purpose |
|---|---|
| `aws_iam_openid_connect_provider.github` | AWS-side trust for `token.actions.githubusercontent.com` |
| `aws_iam_role.terraform_runner` | Role workflows assume; `AdministratorAccess` in mgmt + can chain into member accounts |
| Trust policy condition | `sub = repo:JadenRazo/sre-landing-zone:*` — forks can't assume this |
| Inline `AssumeOrgAccountAccessRoles` policy | Allows chaining into `OrganizationAccountAccessRole` in any Org member |
| Resource-org-ID guard | Even a leaked role can't reach accounts outside our Org (`o-9itq8iim1q`) |

## Apply

```bash
cd infra/07-cicd
terraform init
terraform apply
```

Then add the role ARN to the repo as a GitHub Actions variable (auto-output by the apply):

```bash
gh variable set AWS_ROLE_ARN --body "<terraform_runner_role_arn from outputs>"
```

## Cross-cert mapping

- **SAA**: Domain 1 (Secure) — least-privilege IAM, federated identity, no static keys
- **CCSP**: Domain 4 (App Sec), Domain 5 (Sec Ops) — CI/CD security controls
- **AZ-204 conceptual**: GitHub Actions + Microsoft Entra federation (same OIDC pattern)

## Cost

$0/month. OIDC providers and IAM roles are free.
