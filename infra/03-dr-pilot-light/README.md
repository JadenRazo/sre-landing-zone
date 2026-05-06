# Phase 3 — DR: Pilot Light to us-east-1

Demonstrates the **Pilot Light** disaster-recovery pattern — one of four AWS-canonical patterns (Backup/Restore, **Pilot Light**, Warm Standby, Multi-Site Active/Active). The standby region exists with all infrastructure provisioned but tasks at 0 — failover is a single `aws ecs update-service --desired-count 2` away.

## What this creates

| Where | Resource |
|---|---|
| workloads-dev us-east-1 | VPC (10.20.0.0/16), 2 public subnets, IGW, ALB `sre-alb-dr`, target group |
| workloads-dev us-east-1 | ECS cluster `sre-workloads-dev-dr`, task def, service @ desiredCount=0 |
| workloads-dev us-east-1 | CloudWatch log group `/ecs/sre-reference-app` |
| workloads-dev us-west-2 | ECR replication config (replicates to us-east-1) |
| workloads-dev us-west-2 + us-east-1 | DynamoDB Global Table `sre-feature-flags` (2 replicas) |
| mgmt us-east-1 | 2 Route 53 health checks (one per ALB), 1 CloudWatch alarm |

## Estimated cost (~$17/mo while up)

| Component | $/mo |
|---|---|
| DR ALB | $16 (Free Tier covers first 12 mo if not exceeded) |
| Route 53 health checks (2) | $1 |
| ECR replication | $0.10 (per-GB; image is small) |
| DynamoDB Global Table | $0 at idle (free tier) |
| Standby ECS @ 0 tasks | $0 |
| **Total** | **~$17/mo** |

Tear down between sessions: `terraform destroy` from this directory. Phase 2 stays up independently.

## Apply

Phase 0 + 1 + 2 + 6 must be applied. Phase 6's auto-stop ONLY scales the primary; DR you scale manually during drills.

```bash
cd /root/projects/sre-landing-zone/infra/03-dr-pilot-light
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=phase3.tfplan
terraform apply phase3.tfplan
```

## Failover drill (the portfolio screenshot)

```bash
# Phase 2 must be up (primary serving traffic)
cd ../02-workload-dev && make up && cd ../03-dr-pilot-light

bash failover-drill.sh
```

The script:
1. Confirms primary serves 200
2. Scales primary to 0 (simulates regional failure)
3. Scales DR to 2
4. Polls DR ALB until it serves 200; reports time-to-recovery
5. Reverses (primary back to 1, DR back to 0)

Capture the terminal output as `screenshots/10-failover-drill.png`. Typical recovery time: 60–120 seconds (Fargate cold-start dominates).

## Verify (post-apply, before drill)

```bash
# DR ALB exists and is provisioning
aws elbv2 describe-load-balancers --region us-east-1 --names sre-alb-dr \
  --query "LoadBalancers[0].State.Code"

# Global Table replicas in both regions
aws dynamodb describe-table --table-name sre-feature-flags --region us-west-2 \
  --query "Table.Replicas[].RegionName"

# ECR replication active
aws ecr describe-registry --region us-west-2 --query "replicationConfiguration"
```

## Cross-cert mapping

- **SAA**: Resilient Architectures (heavy — Pilot Light vs. Warm Standby vs. Active-Active is the most-tested DR concept)
- **CCSP**: Domain 5 (BCP/DR), Domain 6 (legal: data residency across regions)
- **Cloud+**: Disaster recovery patterns, RTO/RPO trade-offs
- **AZ-204 conceptual**: Azure Site Recovery + Traffic Manager + Cosmos DB multi-region writes
