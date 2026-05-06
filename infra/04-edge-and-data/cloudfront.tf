# CloudFront distribution in front of the ALB. No custom domain — uses the
# auto-assigned `*.cloudfront.net` for the demo. Adding a custom domain
# requires Route 53 + ACM cert in us-east-1, deferred to a future polish.

resource "aws_cloudfront_distribution" "main" {
  provider            = aws.workloads_dev
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "sre-landing-zone edge — fronting workloads-dev ALB"
  price_class         = "PriceClass_100" # cheapest tier: NA + EU edges only; sufficient for demo
  web_acl_id          = aws_wafv2_web_acl.cloudfront.arn
  default_root_object = ""

  origin {
    domain_name = data.aws_lb.origin.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # ALB is HTTP-only; Phase 4-polish would add ACM on the ALB
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS-managed CachingDisabled policy (use CachingOptimized to actually cache;
    # disabled here because the SRE app's responses are dynamic and uncacheable).
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer
  }

  restrictions {
    geo_restriction {
      restriction_type = length(var.geo_allowed_countries) > 0 ? "whitelist" : "none"
      locations        = var.geo_allowed_countries
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # uses *.cloudfront.net's cert
  }

  tags = { Name = "sre-cloudfront" }
}
