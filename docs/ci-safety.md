# CI and deployment safety

## Why pull requests do not run a live Terraform plan

Each phase uses cross-account AWS data sources and, until remote-state migration
is complete, some phases still depend on local state. A pull-request plan would
therefore need an OIDC token, live account access, current state, and all phase
variables. When any one of those external dependencies is unavailable, every
patch turns red for reasons unrelated to its code.

The required pull-request gate is deliberately credential-free. It formats,
initializes with `-backend=false`, and validates every phase. This proves syntax,
provider constraints, and module wiring without reading state or AWS APIs.

## Authorized write paths

- `terraform apply` is manual-only, uses the `production` GitHub Environment,
  restricts the target to a fixed phase list, and requires the operator to type
  that exact phase path.
- `nightly teardown (cost guard)` is currently manual-only. It requires the
  phrase `destroy-costly-phases` and serializes the three cost-bearing phases.
- Both workflows use GitHub OIDC and pinned Actions. No long-lived AWS access
  key belongs in this repository or its GitHub secrets.

Before either workflow is invoked, verify the target account, the backend for
that phase, the proposed operation, the GitHub Environment protection rules,
and the rollback or teardown path. CI repair never authorizes a cloud change.

## Local static validation

```bash
bash scripts/validate-terraform.sh
```

The script may download providers, but it does not configure a backend, read
state, assume an IAM role, or call AWS.
