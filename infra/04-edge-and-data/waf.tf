# AWS WAF web ACL for CloudFront. Web ACLs that attach to CloudFront MUST be
# in us-east-1 — that's a hard AWS rule and a frequent SAA gotcha.
#
# Three rules:
#   1. AWSManagedRulesCommonRuleSet     — OWASP-style baseline
#   2. AWSManagedRulesKnownBadInputsRuleSet — exploit pattern signatures
#   3. Custom rate limit                — 1000 req per IP per 5 min
#
# Each rule = $1/mo. Web ACL itself = $5/mo. Total = $8/mo while attached.

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.workloads_dev_useast1
  name     = "sre-cloudfront-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-ruleset"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "sre-cloudfront-waf"
    sampled_requests_enabled   = true
  }
}
