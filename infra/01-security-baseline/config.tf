# AWS Config: records resource configuration changes for compliance evaluation.
#
# Three pieces:
#   1. Recorder + delivery channel in EACH account — what to record + where to ship
#   2. An aggregator in audit-security — single pane of glass across the Org
#   3. A small conformance pack — actual rules to evaluate against
#
# Cost levers:
#   - Recording frequency: DAILY (default) is much cheaper than CONTINUOUS
#   - Resource scope: we record ALL_SUPPORTED + global resources; tighter scope
#     would save money but tightens the audit trail
#   - Conformance pack size: we use a HAND-PICKED 8 rules, not the 200+ in the
#     full Operational Best Practices pack. Each rule costs ~$0.001/eval × N evals.

# IAM role that AWS Config assumes to read resources. Each account that records
# needs one. We only set up management here; the workload accounts will get
# their recorders provisioned in Phase 2 alongside their VPCs.
resource "aws_iam_role" "config_recorder" {
  name = "AWSConfigRecorderRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_recorder" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "management" {
  name     = "default"
  role_arn = aws_iam_role.config_recorder.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  recording_mode {
    recording_frequency = var.config_recording_frequency
  }
}

resource "aws_config_delivery_channel" "management" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.log_archive.id
  # No s3_key_prefix: drops Config logs into the standard AWSLogs/<acct>/Config/
  # layout, which matches the bucket policy's allow-list pattern.

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.management]
}

resource "aws_config_configuration_recorder_status" "management" {
  name       = aws_config_configuration_recorder.management.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.management]
}

# Aggregator in audit-security: pulls Config data from every Org account into
# one queryable place. Domain 6 of CCSP, audit-evidence-style use case.
resource "aws_iam_role" "config_aggregator" {
  provider = aws.audit_security
  name     = "AWSConfigAggregatorRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  provider   = aws.audit_security
  role       = aws_iam_role.config_aggregator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

# Delegate AWS Config admin to audit-security so it can run an org-wide
# aggregator. Without this the aggregator create returns
# OrganizationAccessDeniedException.
resource "aws_organizations_delegated_administrator" "config" {
  account_id        = local.accounts.audit_security
  service_principal = "config.amazonaws.com"
}

resource "aws_config_configuration_aggregator" "org" {
  provider   = aws.audit_security
  depends_on = [aws_organizations_delegated_administrator.config]
  name       = "sre-org-aggregator"

  organization_aggregation_source {
    all_regions = false
    regions     = [var.home_region, "us-east-1"]
    role_arn    = aws_iam_role.config_aggregator.arn
  }
}

# Hand-picked conformance pack: 8 rules, all directly relevant to SAA + CCSP.
# Each rule is a managed AWS Config rule (no custom Lambda needed).
locals {
  config_rules = {
    s3-bucket-public-read-prohibited  = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    s3-bucket-public-write-prohibited = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
    s3-bucket-ssl-requests-only       = "S3_BUCKET_SSL_REQUESTS_ONLY"
    iam-root-access-key-check         = "IAM_ROOT_ACCESS_KEY_CHECK"
    iam-user-mfa-enabled              = "IAM_USER_MFA_ENABLED"
    encrypted-volumes                 = "ENCRYPTED_VOLUMES"
    rds-storage-encrypted             = "RDS_STORAGE_ENCRYPTED"
    cloudtrail-enabled                = "CLOUD_TRAIL_ENABLED"
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.config_rules

  name = each.key

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder_status.management]
}
