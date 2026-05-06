output "cloudfront_domain" {
  description = "CloudFront *.cloudfront.net domain. Use this instead of the ALB."
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_id" {
  description = "Distribution ID for invalidations: aws cloudfront create-invalidation --distribution-id <this> --paths '/*'"
  value       = aws_cloudfront_distribution.main.id
}

output "waf_web_acl_arn" {
  description = "WAF web ACL ARN (us-east-1)."
  value       = aws_wafv2_web_acl.cloudfront.arn
}

output "cognito_hosted_ui_url" {
  description = "Cognito Hosted UI login page."
  value       = "https://${aws_cognito_user_pool_domain.hosted_ui.domain}.auth.${var.home_region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.web.id}&response_type=code&scope=openid+email+profile&redirect_uri=${urlencode(var.cognito_callback_urls[0])}"
  sensitive   = true # client_id is treated as sensitive by the provider
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.main.id
}

output "next_steps" {
  description = "What to do after this apply succeeds."
  value       = <<-EOT

    Phase 4 apply complete. CloudFront distribution may take 10-15 min to fully
    deploy globally (Status: Deploying → Deployed).

    Smoke tests once distribution is Deployed:

    1. Hit CloudFront, check cache header:
       curl -sI https://<cloudfront_domain>/
       # First request: X-Cache: Miss from cloudfront
       # Second:        X-Cache: Hit from cloudfront (or RefreshHit)

    2. Trip the WAF (synthetic SQLi):
       curl "https://<cloudfront_domain>/?id=' OR '1'='1"
       # Expect 403

    3. Geo-restrict test (only if you have a VPN to a non-allowed country)

    4. Hit the Cognito Hosted UI:
       open "<cognito_hosted_ui_url>"
       # Should render Cognito-branded login page

    5. Tear down between sessions: terraform destroy (~$8/mo savings)
  EOT
}
