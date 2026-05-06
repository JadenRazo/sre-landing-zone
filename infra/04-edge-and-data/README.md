# Phase 4 — Edge, data, and identity

CloudFront in front of the ALB, AWS WAF for L7 protection, Cognito User Pool for identity. Demonstrates the SAA-favored "edge before origin" pattern and the CCSP-relevant federated identity setup.

## What this creates

| Where | Resource |
|---|---|
| workloads-dev us-east-1 | WAF web ACL `sre-cloudfront-waf` with 3 rules (Common, KnownBadInputs, RateLimit) |
| workloads-dev us-west-2 | CloudFront distribution fronting the Phase 2 ALB |
| workloads-dev us-west-2 | Cognito User Pool `sre-users` + Hosted UI domain + web app client |

## Estimated cost (~$8–10/mo while up)

| Component | $/mo |
|---|---|
| CloudFront | $0 (free tier: 1 TB egress, 10M HTTP req — we'll never hit) |
| WAF web ACL | $5 |
| WAF rules (3) | $3 |
| Cognito User Pool | $0 (free tier: 50k MAU) |
| **Total** | **~$8/mo** |

## Apply

Phase 0 + 1 + 2 must be applied. Phase 3 + 6 are independent.

```bash
cd /root/projects/sre-landing-zone/infra/04-edge-and-data
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=phase4.tfplan
terraform apply phase4.tfplan
```

**CloudFront deployment takes 10–15 minutes** to propagate globally. The `terraform apply` returns when the distribution is "Deploying" — wait until "Deployed" before smoke-testing.

```bash
# Watch deployment status
DIST_ID=$(terraform output -raw cloudfront_id)
watch "aws cloudfront get-distribution --id $DIST_ID --query 'Distribution.Status'"
```

## Smoke tests

```bash
CF=$(terraform output -raw cloudfront_domain)

# 1. CloudFront serves through to origin
curl -sI "https://$CF/" | grep -E "^(HTTP|x-cache)"
# Repeat — second request should show different x-cache value

# 2. WAF blocks SQLi pattern
curl -sI "https://$CF/?id=' OR '1'='1" | head -1
# Expect HTTP/2 403

# 3. WAF rate limit (fire 1100 requests in <5 min)
for i in $(seq 1 1100); do curl -s -o /dev/null "https://$CF/" & done; wait
# Subsequent requests within the 5-min window should 403

# 4. Cognito Hosted UI loads (open in browser)
echo "$(terraform output -raw cognito_hosted_ui_url)"
```

## Cross-cert mapping

- **SAA**: Secure (WAF managed rules, Cognito federation), Performing (CloudFront edge caching), Cost-Optimized (CloudFront price class)
- **CCSP**: Domain 5 (Cloud Sec Ops — WAF, federation), Domain 4 (App Sec — OWASP Top 10 mapping)
- **Cloud+**: CDN concepts, identity federation
- **AZ-204 conceptual**: Front Door + WAF + Microsoft Entra External ID
