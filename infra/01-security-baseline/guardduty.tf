# GuardDuty: continuous threat detection on VPC Flow Logs, DNS query logs, and
# CloudTrail event history. We delegate administration to audit-security so
# findings aggregate there, then auto-enroll all org accounts.
#
# Cost discipline: we explicitly DISABLE the cost-amplifier features:
#   - S3 Protection (data event mining)
#   - EKS Protection
#   - Malware Protection (snapshots EBS volumes)
#   - RDS Protection
#   - Lambda Protection
# These can each 5-10x your GuardDuty bill. Default features only = ~$1-2/mo
# at idle for this project's traffic.

# Step 1: from management, delegate the admin role to audit-security.
resource "aws_guardduty_organization_admin_account" "delegate" {
  admin_account_id = local.accounts.audit_security
}

# Step 2: in audit-security, create the detector that this org will report to.
resource "aws_guardduty_detector" "audit" {
  provider = aws.audit_security

  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency

  datasources {
    s3_logs {
      enable = false
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = false
        }
      }
    }
  }
}

# Step 3: tell GuardDuty to auto-enroll new accounts and enable existing ones.
resource "aws_guardduty_organization_configuration" "audit" {
  provider = aws.audit_security
  depends_on = [
    aws_guardduty_organization_admin_account.delegate,
    aws_guardduty_detector.audit,
  ]

  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.audit.id

  datasources {
    s3_logs {
      auto_enable = false
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = false
        }
      }
    }
  }
}
