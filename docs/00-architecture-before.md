# Architecture (before): single-account sre-reference-app

The starting state — what `sre-reference-app` looked like at the end of its GameDay run, before this project began.

## Topology

- **Single AWS account** (`569239324174`), `us-west-2` only
- **VPC** with public + private subnets across 2 AZs
- **NAT Gateway** in one public subnet (cost driver)
- **ALB** in public subnets, fronting…
- **ECS Fargate** service in private subnets, 2 tasks, 256 CPU / 512 MB
- **ECR** for the app image
- **CloudWatch** for logs and dashboards
- **CloudWatch alarms** for fast-burn (1h @ 14.4×) and slow-burn (6h @ 6×)
- **GitHub Actions** with OIDC role (`sre-app-deploy` IAM user-equivalent role) for CI/CD

## Application

- **Python 3.12 / Flask / Gunicorn**, runs in a `python:3.12-slim` container
- 3 endpoints: `/` (returns 500 ~5% of the time, configurable via `ERROR_RATE` env var), `/health`, `/work`
- Structured JSON logs to stdout → CloudWatch Logs

## Observability

- CloudWatch dashboard (request count, p50/p99 latency, 5xx rate, ECS task count, target group health, CPU)
- Multi-window burn-rate alarms per Google SRE Workbook:
  - **Fast-burn**: `error_rate > 14.4 * SLO_BUDGET` over 1 hour → page
  - **Slow-burn**: `error_rate > 6 * SLO_BUDGET` over 6 hours → ticket
- Demonstrated 78-second recovery from a controlled task-kill, error rate stayed under threshold

## What's missing (and what Phase 2 onward adds)

| Capability | Before | After |
|---|---|---|
| Account isolation | None — single account does everything | 4-account Org (mgmt / log-archive / audit-security / workloads-dev/prod) |
| Identity | IAM user with long-lived access keys | IAM Identity Center, federated SSO, no static keys |
| Preventive guardrails | None | 4 SCPs (deny root, deny non-approved regions, require IMDSv2, deny disabling security) |
| Centralized audit | App-level CloudWatch only | Org CloudTrail to KMS-encrypted S3 in log-archive, with Object Lock |
| Runtime threat detection | None | GuardDuty org-wide |
| Posture management | None | Security Hub + AWS Config conformance pack |
| Network egress | NAT Gateway ($32/mo) | VPC Interface Endpoints — no public egress |
| Secrets | `ERROR_RATE` env var | Secrets Manager with KMS CMK + rotation |
| Edge | ALB exposed directly | CloudFront + WAF + ACM |
| DR | Single-region | Pilot-Light to us-east-1 with Route 53 failover |
| Cost discipline | Manual destroy | Budgets + EventBridge auto-stop on dev tags |
| Tagging | Ad-hoc | SCP-/TagPolicy-enforced standards |
