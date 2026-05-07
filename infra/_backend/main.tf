# Remote-state backend bootstrap.
#
# Creates the S3 bucket + DynamoDB table that every other phase will use as
# its `terraform { backend "s3" {} }` target. Run this FIRST in a fresh org;
# all other phases then migrate to remote state with `terraform init -migrate-state`.
#
# WHY THIS LIVES IN ITS OWN STACK:
#   The classic chicken-and-egg: you can't manage your backend with the same
#   state file that depends on it. Solution: this stack uses LOCAL state
#   (committed to .gitignore), and every other stack uses S3+DynamoDB.
#
# WHY IT'S SCAFFOLDED BUT NOT YET ADOPTED:
#   Migrating live state from local → S3 mid-project risks corruption if any
#   apply runs against half-migrated state. We scaffolded this for the
#   patterns/cert-prep value but defer the actual migration to a planned
#   maintenance window. See README for the runbook.

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "_backend"
      Owner     = "jadenrazo"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tf_state" {
  bucket = "sre-landing-zone-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Lock table prevents concurrent applies stomping on state.
resource "aws_dynamodb_table" "tf_lock" {
  name         = "sre-landing-zone-tflock"
  billing_mode = "PAY_PER_REQUEST" # always-free at idle volumes
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false # state lock — losing it costs minutes, not data
  }
}

output "backend_config" {
  description = "Drop into each phase's terraform.tf to migrate."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.tf_state.id}"
        key            = "<phase-name>/terraform.tfstate"   # e.g. "00-org-bootstrap/terraform.tfstate"
        region         = "us-west-2"
        dynamodb_table = "${aws_dynamodb_table.tf_lock.id}"
        encrypt        = true
      }
    }
  EOT
}
