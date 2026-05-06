# Org-wide CloudTrail. Created in the management account, records management
# events from every account in the Org, ships to the log-archive S3 bucket.
#
# `is_organization_trail = true` is the magic — it means member accounts can't
# disable or modify it (combined with the deny_disabling_security SCP from
# Phase 0, this is bulletproof).
#
# Cost: management events for the FIRST org-wide trail are free. Data events
# (S3 object-level, Lambda invocations) are NOT free — we don't enable them
# here. Insights events also cost extra; off by default.

resource "aws_cloudtrail" "org" {
  depends_on = [
    aws_s3_bucket_policy.log_archive,
  ]

  name                          = "sre-org-trail"
  s3_bucket_name                = aws_s3_bucket.log_archive.id
  s3_key_prefix                 = ""
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.log_archive.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
