# Screenshots checklist

13 console captures that complete the portfolio narrative. Mirrors `sre-reference-app/screenshots/` style: numbered, descriptive filename, captured during a specific moment.

**Save all to** `screenshots/NN-name.png`. Use **macOS Cmd+Shift+4** or **Win Snip & Sketch** with the cursor not visible. PNG, no annotations needed — the diagrams already explain.

## Active prep

Before capturing, ensure:
- All 4 phases applied (Phase 2, 3, 4 actively up)
- Real sre-reference-app image is deployed (`make push-real-image` was run)
- A load generator has been hammering the ALB for at least 30 min so dashboards have data:
  ```bash
  ALB=$(cd infra/02-workload-dev && terraform output -raw alb_dns_name)
  while true; do curl -s -o /dev/null "http://$ALB/"; sleep 0.5; done
  ```

## The 13

### 01-org-accounts.png
- **Console**: AWS Organizations → AWS accounts (in management account)
- **Snap when**: Tree view shows all 5 accounts with their OU groupings visible
- **Highlight**: 5 accounts, 3 OUs, the SCP indicator chips on each OU

### 02-identity-center.png
- **Console**: IAM Identity Center → AWS accounts
- **Snap when**: jadenrazo user has been assigned to all 4 member accounts
- **Highlight**: Permission set column showing AdminAccess assignments

### 03-cloudtrail-org-trail.png
- **Console**: CloudTrail → Trails (any account works; trails list is global-ish)
- **Snap when**: `sre-org-trail` is visible
- **Highlight**: "Multi-region trail = Yes" + "Organization trail = Yes" + "Encryption = KMS" columns

### 04-guardduty-delegated.png
- **Console**: GuardDuty (in audit-security via SSO) → Settings → Accounts
- **Snap when**: All 5 org accounts show as "Auto-enrolled / Delegated admin"
- **Highlight**: Audit-security as the delegated admin badge

### 05-securityhub-findings.png
- **Console**: Security Hub (in audit-security) → Findings
- **Snap when**: At least 24 hours have passed (initial findings need time)
- **Highlight**: A few HIGH-severity findings with their compliance control IDs (e.g., `S3.2`, `IAM.6`)

### 06-budget-alerts.png
- **Console**: Billing → Budgets (in management)
- **Snap when**: 3 budgets are visible
- **Highlight**: The 4 forecast thresholds on the $100 budget

### 07-ecs-service-running.png
- **Console**: ECS (in workloads-dev via SSO) → Clusters → sre-workloads-dev → Services
- **Snap when**: `sre-reference-app` shows 1/1 RUNNING with healthy targets
- **Highlight**: Service running count + target group health

### 08-cloudwatch-dashboard.png
- **Console**: CloudWatch (in workloads-dev) → Dashboards → sre-reference-app
- **Snap when**: Real image deployed + load generator running for 30+ min
- **Highlight**: All 3 widgets populated with actual metric movement (RequestCount + 5xx + p99 latency + task count)

### 09-burn-rate-alarms.png
- **Console**: CloudWatch → Alarms (in workloads-dev)
- **Snap when**: Both alarms in OK state with metric values visible
- **Highlight**: `sre-reference-app-fast-burn-1h` + `sre-reference-app-slow-burn-6h`

### 10-failover-drill.png
- **Console**: TERMINAL — `bash failover-drill.sh` output
- **Snap when**: Script has completed; the colored "DR healthy after Ns" line is visible
- **Highlight**: The recovery time line + the reverse confirmation

### 11-cloudfront-distribution.png
- **Console**: CloudFront (any account that has cross-acct view, or login as workloads-dev) → Distributions
- **Snap when**: Distribution status is "Deployed" (not "Deploying")
- **Highlight**: Origin = ALB DNS + WAF web ACL association + status badge

### 12-waf-rules.png
- **Console**: WAF & Shield (us-east-1) → Web ACLs → sre-cloudfront-waf
- **Snap when**: 3 rules listed
- **Highlight**: AWSManagedRulesCommonRuleSet, AWSManagedRulesKnownBadInputsRuleSet, RateLimitPerIP

### 13-cost-explorer-by-tag.png
- **Console**: Cost Explorer → group by Tag → Project → filter to date range covering the build
- **Snap when**: After Phase 6 has been running long enough to capture meaningful spend
- **Highlight**: `sre-landing-zone` tag, total spend, breakdown by service or by linked account

## After capture

1. Move all 13 PNGs to `screenshots/` (root of repo)
2. Run `git add screenshots/` and commit
3. The README's screenshot section will auto-resolve the relative paths
