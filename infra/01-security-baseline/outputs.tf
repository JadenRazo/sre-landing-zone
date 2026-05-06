output "log_archive_bucket" {
  description = "Bucket name receiving Org CloudTrail + Config logs."
  value       = aws_s3_bucket.log_archive.id
}

output "log_archive_kms_key_arn" {
  description = "KMS CMK encrypting log-archive bucket."
  value       = aws_kms_key.log_archive.arn
}

output "cloudtrail_arn" {
  description = "ARN of the org-wide CloudTrail."
  value       = aws_cloudtrail.org.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID in audit-security (delegated admin)."
  value       = aws_guardduty_detector.audit.id
}

output "config_aggregator_name" {
  description = "AWS Config aggregator name in audit-security."
  value       = aws_config_configuration_aggregator.org.name
}

output "budget_alerts_topic_arn" {
  description = "SNS topic for Budgets alerts. Subscribe email + click confirm in inbox."
  value       = aws_sns_topic.budget_alerts.arn
}

output "next_steps" {
  description = "What to do after this apply succeeds."
  value       = <<-EOT

    Phase 1 apply complete. Next:

    1. CONFIRM your email subscription to the budget-alerts SNS topic
       (AWS sent you an email; click the link). Without this you get no alerts.

    2. Wait ~10 minutes, then verify in the audit-security account console:
       - GuardDuty → Findings (probably empty; that's fine)
       - Security Hub → Findings (will populate within an hour)
       - Config → Aggregators → sre-org-aggregator (rules evaluating)

    3. Smoke test: in management account, create then delete a public S3 bucket.
       The trail event lands in the log-archive bucket within ~5 min,
       and Security Hub should show an S3 finding within an hour.

    4. Move to Phase 2: cd ../02-workload-dev (not yet implemented).
  EOT
}
