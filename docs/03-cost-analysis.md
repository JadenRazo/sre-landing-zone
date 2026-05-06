# Cost analysis

Running ledger of actual AWS spend on this project. Append a new section at the end of every phase. Use `scripts/cost-snapshot.sh` to generate the data.

## Budget

- **Total credits**: $120 (AWS credits)
- **Hard cap**: $100 (leave $20 buffer for surprise charges + exam-week studying)
- **Phase 2 audit gate**: if month-to-date >$30 by end of Phase 2, stop and audit

## Estimated phase costs (from plan)

| Phase | Estimated $/mo | Notes |
|---|---|---|
| 0 — Org bootstrap | $0 | Org/OUs/SCPs/Tag policy/Identity Center are free |
| 1 — Security baseline | $5–15 | Config (~$2), GuardDuty post-trial (~$1–2), CloudTrail S3 (~$1), VPC flow logs S3 (~$1) |
| 2 — Workload (sre-app) | $5–30 | NAT-Gateway-or-not is the swing; endpoints ~$28/mo, NAT $32/mo, session-only ~$3 |
| 3 — DR pilot light | $5–10 | ECR replication + S3 CRR + DynamoDB + Route 53 health checks; standby ECS scaled to 0 |
| 4 — Edge + data | $5–15 | CloudFront free tier covers most; WAF $5/mo + $1/rule, Cognito free tier 50k MAU |
| 6 — Cost controls | $0 | Budgets free; Lambda + EventBridge in always-free tier |

**Theoretical 8-week run cost**: $20–80 if disciplined with teardown between sessions. Buffer for screw-ups.

## Cost-trap awareness

1. **NAT Gateway**: $32/mo per gateway × number of AZs. Single biggest cost. Mitigation: VPC Interface Endpoints OR session-only OR NAT instance.
2. **CloudWatch Logs** (when configured as Flow Logs destination): $0.50/GB ingestion. Mitigation: send VPC Flow Logs to S3 instead.
3. **AWS Config**: $2 per recorder per region per month + $0.001/evaluation. Mitigation: small conformance pack only.
4. **GuardDuty**: free 30-day trial, then per-event/data charges. Mitigation: idle account = ~$1/mo, but ramp up quickly with traffic.
5. **EBS volumes from terminated EC2**: snapshots accrue $0.05/GB-month. Mitigation: lifecycle policies + audit `aws ec2 describe-snapshots --owner-ids self`.
6. **Cross-AZ traffic**: $0.01/GB. Mitigation: keep ALB and tasks in same AZ during demos.

## Actuals

_(Run `make cost-snapshot` after each phase. Auto-appended below.)_


### Snapshot 2026-05-06T21-55-52Z
- Period: 2026-05-01 → 2026-05-06
- Total (Unblended): $null

Top 5 services:
- Amazon Simple Storage Service: $0.0000000091
- AmazonCloudWatch: $0
- Amazon Simple Queue Service: $0
- Amazon Simple Notification Service: $0
- AWS Secrets Manager: $0
