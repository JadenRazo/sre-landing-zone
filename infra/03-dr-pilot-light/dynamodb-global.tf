# DynamoDB Global Table for feature flags. Replicas in both primary + DR regions
# with last-writer-wins semantics. Free tier covers 25GB + 25 RCU/WCU per region.
#
# Why feature flags as the demo workload: forces understanding of LWW semantics,
# which is a real interview question and a SAA exam topic.
#
# Provider 5.x supports `aws_dynamodb_table` with `replica` blocks for global
# tables (formerly two separate resources). Schema must be identical across
# replicas — that's the whole point.

resource "aws_dynamodb_table" "feature_flags" {
  provider     = aws.workloads_dev_primary
  name         = "sre-feature-flags"
  billing_mode = "PAY_PER_REQUEST" # always-free 25 RCU/WCU is provisioned-only; on-demand is what we want for spike tolerance
  hash_key     = "flag_name"

  attribute {
    name = "flag_name"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  replica {
    region_name            = var.dr_region
    point_in_time_recovery = false
  }

  point_in_time_recovery {
    enabled = false # PITR is $0.20/GB-month — off for cert-prep
  }

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    ignore_changes = [replica] # avoid noise from AWS-managed replica state
  }
}

# Seed one flag so the table isn't empty (improves the screenshot).
resource "aws_dynamodb_table_item" "seed_error_rate" {
  provider   = aws.workloads_dev_primary
  table_name = aws_dynamodb_table.feature_flags.name
  hash_key   = aws_dynamodb_table.feature_flags.hash_key

  item = jsonencode({
    flag_name = { S = "error_rate_override" }
    enabled   = { BOOL = false }
    value     = { N = "0.05" }
    note      = { S = "Default error rate. Set enabled=true to override the Secrets Manager value." }
  })
}
