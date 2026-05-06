# Phase 2 — Migrate sre-reference-app into workloads-dev

Re-deploys the SRE app into the `workloads-dev` member account, behind an internet-facing ALB, with Secrets Manager for runtime config and CloudWatch burn-rate alarms. The image defaults to public nginx so the stack works end-to-end before you push your real image.

## What this creates

| Resource | Purpose |
|---|---|
| VPC `10.0.0.0/16` + 2 public + 2 private subnets across 2 AZs | Network foundation |
| Internet Gateway | Public egress for ALB, ECR pulls (via NAT) |
| 1 NAT Gateway (single AZ) | Outbound internet for private-subnet tasks. **$32/mo — the cost killer** |
| VPC Flow Logs to S3 (REJECTs only) | Centralized network audit in log-archive bucket |
| 2 Security Groups | ALB-from-internet, task-from-ALB-only |
| Application Load Balancer (HTTP:80) | Public entry point |
| Target Group (IP-target, /healthcheck) | Routes ALB → tasks |
| ECR repo `sre-reference-app` | For your real image when ready |
| Secrets Manager `sre-reference-app/error-rate` | Runtime config (rotatable) |
| ECS Fargate cluster + task def + service (1 task) | The workload |
| 2 IAM roles (task execution, task) | ECS pulls image, writes logs, reads secrets |
| CloudWatch log group + dashboard | Per-task logs + visual ops view |
| 2 burn-rate alarms (fast 1h/14.4×, slow 6h/6×) | The SRE narrative — Google SRE Workbook pattern |

## Estimated cost (the math)

| Component | $/mo if 24/7 | If 4hr/day study cadence |
|---|---|---|
| NAT Gateway | $32.85 | ~$5.50 |
| ALB | $16 (Free Tier covers first 12 mo) | $0 |
| Fargate task (256/512) | $7.30 | ~$1.20 |
| Secrets Manager | $0.40 | $0.40 |
| Elastic IP for NAT | $0 (attached) | $0 |
| CloudWatch Logs | <$1 | <$0.20 |
| **Total** | **~$57/mo** | **~$7/mo** |

The single biggest variable is whether NAT is up 24/7 or torn down between sessions. **Use `make down`.** The whole stack rebuilds in ~3 minutes — discipline beats automation here.

## Apply

Phase 0 + 1 must already be applied. This stack reads the account map from Phase 0's SSM parameter.

```bash
cd /root/projects/sre-landing-zone/infra/02-workload-dev
cp terraform.tfvars.example terraform.tfvars   # defaults are fine for first apply
make up      # = terraform apply -auto-approve
```

Takes ~3 minutes. NAT Gateway + ALB are the slow ones (~90s each).

## Verify

```bash
make curl    # GET / against the ALB → should be HTTP 200 (nginx welcome page)
make logs    # tail CloudWatch logs from the running task
```

Console (login as workloads-dev via Identity Center):
- ECS → Clusters → `sre-workloads-dev` → Services → `sre-reference-app` (1/1 Running)
- CloudWatch → Dashboards → `sre-reference-app`
- CloudWatch → Alarms → 2 alarms in OK state

## Daily workflow

```bash
make up           # start of study session, ~3 min
# ...do work, take screenshots, study the dashboard...
make down         # end of session, ~2 min, $0/mo from now
```

If you want to keep the infra but pause the running task (saves ~$0.05/hr but NOT NAT cost):

```bash
make scale-zero   # task count 0, NAT still up
make scale-one    # resume
```

For real cost discipline: **prefer `make down` over `scale-zero`.** NAT is the killer, not Fargate.

## Swap in your real sre-reference-app image

```bash
# 1. Get ECR URL
ECR_URL=$(terraform output -raw ecr_repository_url)
ACCT=$(echo $ECR_URL | cut -d. -f1)

# 2. Login (assume role into workloads-dev first, then login)
aws sts assume-role --role-arn arn:aws:iam::$ACCT:role/OrganizationAccountAccessRole \
    --role-session-name docker-push --query Credentials > /tmp/c.json
export AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId /tmp/c.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey /tmp/c.json)
export AWS_SESSION_TOKEN=$(jq -r .SessionToken /tmp/c.json)

aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin $ECR_URL

# 3. Build + push (from your local sre-reference-app repo)
cd ~/sre-reference-app
docker build -t sre-reference-app .
docker tag sre-reference-app:latest $ECR_URL:latest
docker push $ECR_URL:latest

# 4. Update tfvars to use the new image
cd /root/projects/sre-landing-zone/infra/02-workload-dev
echo 'container_image = "'$ECR_URL':latest"' >> terraform.tfvars
echo 'container_port  = 8080' >> terraform.tfvars
make up

# 5. Cleanup
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
rm /tmp/c.json
```

Once the real image is running, the burn-rate alarms become meaningful (5% baseline error rate = visible blip on the dashboard, no alarm; bump ERROR_RATE to 0.20 in Secrets Manager and you'll trip the fast-burn alarm within an hour).

## Prod-grade alternative (for the portfolio writeup)

The plan calls out **VPC Interface Endpoints replacing NAT** as the SAA-favored "no public internet egress" pattern. We didn't default to it because in 2 AZs it's $58/mo (worse than NAT). For the portfolio screenshot:

1. Switch `az_count = 1`
2. Add Interface Endpoints to `network.tf` for: `ecr.api`, `ecr.dkr`, `logs`, `secretsmanager`, `sts` (5 endpoints × $7.30/mo = $36.50)
3. Add an S3 Gateway Endpoint (free)
4. `terraform destroy -target=aws_nat_gateway.main` and remove the NAT route
5. Tasks now reach ECR/Logs/Secrets without ever touching the public internet

That's a separate study session — not part of the default Phase 2 path.

## Cross-cert mapping

- **CLF**: VPC, subnets, ECS, ALB, ECR, Secrets Manager, CloudWatch — all in scope
- **SAA**: Resilient Architectures (Multi-AZ ALB), Secure (private-subnet workload, no public IPs), Cost-Optimized (NAT vs. endpoints trade-off, Fargate vs. EC2)
- **CCSP**: Secrets management, network segmentation, encryption-in-transit (ALB)
- **AZ-204 conceptual**: VNet → VPC, Container Apps → Fargate, Key Vault → Secrets Manager, Front Door → ALB+CloudFront
