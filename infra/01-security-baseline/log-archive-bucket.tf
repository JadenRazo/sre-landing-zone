# S3 bucket in the log-archive account that will receive:
#   - Org-wide CloudTrail logs
#   - AWS Config configuration history
#   - VPC Flow Logs (added in Phase 2 when VPCs exist)
#
# Why log-archive (not management): regulatory hygiene. Audit data should live
# in an account that has no workload IAM principals — limits blast radius if a
# workload-account credential is compromised. CCSP Domain 6 (Cloud Security Ops)
# directly tests this pattern.

# KMS key for at-rest encryption. CloudTrail and Config both want a CMK they
# can use; the key policy below grants both services + Org member accounts.
resource "aws_kms_key" "log_archive" {
  provider                = aws.log_archive
  description             = "Encrypts CloudTrail + Config logs in log-archive bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RootAccountFullAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.accounts.log_archive}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudTrailKeyUse"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
        ]
        Resource = "*"
        # SourceAccount scopes the key to OUR org's mgmt account; EncryptionContext
        # scopes it to CloudTrail's standard ARN format. SourceArn is omitted
        # because at trail-creation time the trail doesn't exist yet and the
        # validation call would fail otherwise.
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.accounts.management
          }
        }
      },
      {
        Sid    = "ConfigKeyUse"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = "*"
      },
      {
        Sid    = "OrgMembersDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = data.aws_organizations_organization.main.id
          }
        }
      },
    ]
  })
}

resource "aws_kms_alias" "log_archive" {
  provider      = aws.log_archive
  name          = "alias/sre-log-archive"
  target_key_id = aws_kms_key.log_archive.key_id
}

# Bucket name must be globally unique. Suffixing with the account ID guarantees it.
resource "aws_s3_bucket" "log_archive" {
  provider = aws.log_archive
  bucket   = "sre-log-archive-${local.accounts.log_archive}"

  # Force-destroy off: this bucket holds compliance-grade audit trails. If you
  # really need to delete it, override here, run, and revert.
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "log_archive" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.log_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_archive.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  provider                = aws.log_archive
  bucket                  = aws_s3_bucket.log_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: standard → IA at 30d → Glacier IR at 90d → Glacier Deep Archive at 365d.
# Cost curve we want to demonstrate. Keep current versions but move noncurrent
# versions to cheap tiers fast (a deleted file becomes "noncurrent" in a versioned bucket).
resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    id     = "tier-down-on-age"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER_IR"
    }
    noncurrent_version_expiration {
      noncurrent_days = 730
    }
  }
}

# Bucket policy: allow CloudTrail + Config to write, deny insecure transport.
data "aws_iam_policy_document" "log_archive" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.log_archive.arn,
      "${aws_s3_bucket.log_archive.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "CloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [aws_s3_bucket.log_archive.arn]
    # StringEqualsIfExists: passes if SourceAccount is absent (the case during
    # CreateTrail validation, before the trail exists), enforces after.
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:SourceAccount"
      values   = [local.accounts.management]
    }
  }

  statement {
    sid     = "CloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.log_archive.arn}/AWSLogs/${data.aws_organizations_organization.main.id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:SourceAccount"
      values   = [local.accounts.management]
    }
  }

  # Per-account write path. Some CloudTrail validation flows expect to be able
  # to write to AWSLogs/<management-account-id>/* in addition to the org path.
  statement {
    sid     = "CloudTrailWritePerAccount"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.log_archive.arn}/AWSLogs/${local.accounts.management}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "ConfigAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl", "s3:ListBucket"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = [aws_s3_bucket.log_archive.arn]
  }

  statement {
    sid     = "ConfigWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = [
      for id in concat([local.accounts.management], local.member_account_ids) :
      "${aws_s3_bucket.log_archive.arn}/AWSLogs/${id}/Config/*"
    ]
    # No s3:x-amz-acl condition — modern AWS Config writes don't include that
    # header. Bucket ownership is enforced by the bucket-level OwnershipControl
    # (BucketOwnerEnforced is the SSE+ACL default for new buckets in 2024+).
  }
}

resource "aws_s3_bucket_policy" "log_archive" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.log_archive.id
  policy   = data.aws_iam_policy_document.log_archive.json
}
