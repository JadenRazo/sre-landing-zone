# Route 53 hosted zone for `cloud.raizhost.com`. The parent zone (`raizhost.com`)
# stays in your existing DNS provider (Cloudflare). After this applies, you
# add 4 NS records at the parent for `cloud.raizhost.com` pointing at the
# nameservers AWS assigned — that's the one-time delegation.
#
# After delegation, every subsequent project just creates records under
# `cloud.raizhost.com` via Terraform with no manual DNS work.
#
# Cost: $0.50/mo per hosted zone + $0.40 per million queries.

provider "aws" {
  region = var.home_region

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "08-dns-delegation"
      Owner     = var.owner_tag
    }
  }
}

resource "aws_route53_zone" "cloud_raizhost" {
  name    = var.subdomain
  comment = "Subdomain delegated from Cloudflare-managed raizhost.com — used by all portfolio projects"
}
