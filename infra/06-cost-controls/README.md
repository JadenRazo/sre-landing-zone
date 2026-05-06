# Phase 6 — Cost discipline & auto-teardown

Three layers of cost protection: **anomaly detection**, **scheduled auto-stop**, and **tag enforcement** (re-attempt of Phase 0's deferred Tag Policy).

## What this creates

| Where | Resource | Purpose |
|---|---|---|
| mgmt | `aws_ce_anomaly_monitor` (service-level) | ML-driven cost spike detection across all services |
| mgmt | `aws_ce_anomaly_subscription` | Routes anomalies > $5 impact to existing budget-alerts SNS |
| mgmt | Lambda `sre-auto-stop` (Python 3.12) | Cross-account scale-to-zero of the workloads-dev ECS service |
| mgmt | IAM role `sre-auto-stop-lambda` | Lambda's exec role; only allowed to assume the executor in workloads-dev |
| mgmt | EventBridge rule (cron 0 4 * * ? *) | Daily 8 PM PST trigger for the Lambda |
| workloads-dev | IAM role `AutoStopExecutorRole` | What the Lambda assumes; scoped `ecs:UpdateService` on one service |
| Org-wide | Tag Policy `tag-standards` (via CLI) | Standard tag keys: Environment, Owner, CostCenter, Project |

## Cost

~**$0/month**:
- Cost Anomaly Detection: free service
- Lambda: 1 daily invocation × 30 days × ~3s × 128MB = effectively $0 (well under always-free 1M req/400k GB-seconds)
- EventBridge: free for AWS service rules
- Tag Policy: free (Org policies are free)

## Apply

Phase 0 + 1 + 2 must be applied. This stack reads the SSM account map and references the Phase 1 SNS topic.

```bash
cd /root/projects/sre-landing-zone/infra/06-cost-controls
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=phase6.tfplan
terraform apply phase6.tfplan
```

## Verify

```bash
# 1. Lambda exists
aws lambda get-function --function-name sre-auto-stop --query "Configuration.[FunctionName,State]"

# 2. EventBridge rule scheduled
aws events list-rules --name-prefix sre-auto-stop --query "Rules[].[Name,State,ScheduleExpression]"

# 3. Cost Anomaly monitor active
aws ce get-anomaly-monitors --query "AnomalyMonitors[].[MonitorName,MonitorArn]"

# 4. Tag Policy exists
aws organizations list-policies --filter TAG_POLICY --query "Policies[].[Name,Id]"
```

## Test the auto-stop end-to-end

```bash
# Make sure Phase 2 is up
cd ../02-workload-dev && make up && cd ../06-cost-controls

# Confirm desiredCount=1 in workloads-dev
aws sts assume-role --role-arn arn:aws:iam::422783588447:role/OrganizationAccountAccessRole \
  --role-session-name verify --query Credentials > /tmp/wd.json
AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId /tmp/wd.json) \
AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey /tmp/wd.json) \
AWS_SESSION_TOKEN=$(jq -r .SessionToken /tmp/wd.json) \
  aws ecs describe-services --cluster sre-workloads-dev --services sre-reference-app \
  --query "services[0].desiredCount"

# Invoke the Lambda manually
aws lambda invoke --function-name sre-auto-stop /tmp/out.json
cat /tmp/out.json

# Confirm desiredCount=0
AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId /tmp/wd.json) \
AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey /tmp/wd.json) \
AWS_SESSION_TOKEN=$(jq -r .SessionToken /tmp/wd.json) \
  aws ecs describe-services --cluster sre-workloads-dev --services sre-reference-app \
  --query "services[0].desiredCount"

rm /tmp/wd.json /tmp/out.json
```

## Cross-cert mapping

- **CLF**: AWS Lambda, IAM, EventBridge, Cost Explorer concepts
- **SAA**: Cost-Optimized Architectures (heavy), cross-account IAM (Domain 1)
- **CCSP**: Domain 5 (Cloud Sec Ops) — cross-account least-privilege automation
- **AZ-204 conceptual**: Azure Functions + Azure Logic Apps + Cost Management Budgets
