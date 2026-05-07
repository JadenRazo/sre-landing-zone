output "zone_id" {
  description = "Hosted zone ID. Future projects reference this via SSM or by re-importing this stack as a data source."
  value       = aws_route53_zone.cloud_raizhost.zone_id
}

output "zone_name" {
  description = "Subdomain managed by this hosted zone."
  value       = aws_route53_zone.cloud_raizhost.name
}

output "name_servers" {
  description = "The 4 NS records to add at your parent DNS provider (Cloudflare) under the 'cloud' subdomain."
  value       = aws_route53_zone.cloud_raizhost.name_servers
}

output "delegation_instructions" {
  description = "How to wire up the delegation in Cloudflare."
  value       = <<-EOT

    DELEGATION STEP — do this once in Cloudflare:

    1. Cloudflare → DNS → raizhost.com
    2. Add 4 NS records:
         Type: NS
         Name: cloud
         TTL:  Auto (or 300)
         Targets: ${join(", ", aws_route53_zone.cloud_raizhost.name_servers)}

    3. Set proxy status to DNS-only (gray cloud) for these NS records.
       NS records can't be proxied through Cloudflare — they have to be
       resolved natively.

    4. Wait ~5 minutes for Cloudflare to propagate. Verify:
         dig cloud.raizhost.com NS +short
       Should return 4 awsdns nameservers.

    After delegation, every future project's Terraform can:
         data "aws_route53_zone" "cloud" {
           name = "cloud.raizhost.com"
         }
         resource "aws_route53_record" "app" {
           zone_id = data.aws_route53_zone.cloud.zone_id
           name    = "myapp.cloud.raizhost.com"
           type    = "A"
           ...
         }
  EOT
}

# Also write zone metadata to SSM so other projects can look it up without
# a data source on the zone name (faster, doesn't depend on DNS resolution).
resource "aws_ssm_parameter" "zone_id" {
  name        = "/sre-landing-zone/dns/zone-id"
  description = "Route 53 zone ID for cloud.raizhost.com — used by portfolio projects"
  type        = "String"
  value       = aws_route53_zone.cloud_raizhost.zone_id
}

resource "aws_ssm_parameter" "zone_name" {
  name        = "/sre-landing-zone/dns/zone-name"
  description = "Route 53 zone name (cloud.raizhost.com)"
  type        = "String"
  value       = aws_route53_zone.cloud_raizhost.name
}
