# Phase 8 — DNS delegation for `cloud.raizhost.com`

One-time foundation extension. Creates a Route 53 hosted zone in mgmt for `cloud.raizhost.com`. You add 4 NS records at the parent `raizhost.com` (Cloudflare) pointing at AWS — after that, every future project creates records via Terraform with zero manual DNS work.

## What this creates

| Resource | Purpose |
|---|---|
| `aws_route53_zone.cloud_raizhost` | Hosted zone for `cloud.raizhost.com` |
| 2× `aws_ssm_parameter` | Zone ID + zone name in SSM for lookup from any project |

## Cost

$0.50/month per hosted zone + $0.40 per million queries. Negligible.

## Apply

```bash
cd infra/08-dns-delegation
terraform init
terraform apply
```

The `name_servers` output prints 4 NS records. Copy them into Cloudflare.

## Cloudflare delegation steps (one-time)

1. **Cloudflare dashboard** → `raizhost.com` → DNS → Records
2. Add 4 NS records:
   - **Type**: `NS`
   - **Name**: `cloud`
   - **TTL**: Auto (or 300)
   - **Target**: each of the 4 `awsdns-XX.com` / `awsdns-XX.net` / `awsdns-XX.org` / `awsdns-XX.co.uk` nameservers from the Terraform output
3. Save each
4. **Important**: NS records cannot be proxied. They MUST be DNS-only (gray cloud). Cloudflare auto-detects this for NS records.
5. Wait ~5 min for propagation
6. Verify:
   ```bash
   dig cloud.raizhost.com NS +short
   ```
   Should return 4 `*.awsdns-*` nameservers.

## How future projects use it

```hcl
# In any future project's Terraform:
data "aws_route53_zone" "cloud" {
  name = "cloud.raizhost.com"
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.cloud.zone_id
  name    = "myapp.cloud.raizhost.com"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
```

## Verify

```bash
# Zone exists
aws route53 list-hosted-zones --query "HostedZones[?Name=='cloud.raizhost.com.'].[Id,Name]" --output table

# SSM parameters set
aws ssm get-parameter --name /sre-landing-zone/dns/zone-id
aws ssm get-parameter --name /sre-landing-zone/dns/zone-name

# After Cloudflare delegation:
dig cloud.raizhost.com NS +short
```
