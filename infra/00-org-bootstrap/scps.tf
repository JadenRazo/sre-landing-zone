# Service Control Policies. Attached to OUs so the management account is
# never affected — protects break-glass access. Only one statement per SCP
# resource keeps blast-radius and IAM Access Analyzer findings tidy.

# 1. Deny ALL actions performed by the root user. Forces every action through
#    a properly-scoped IAM principal (or Identity Center role).
resource "aws_organizations_policy" "deny_root" {
  depends_on  = [aws_organizations_organization.main]
  name        = "deny-root-user-actions"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Deny any action when the calling principal is the root user."
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyRoot"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        StringLike = {
          "aws:PrincipalArn" = "arn:aws:iam::*:root"
        }
      }
    }]
  })
}

# 2. Deny use of regions outside the approved list. Global services (IAM,
#    Organizations, Route 53, CloudFront, etc.) are excluded via NotAction
#    because they don't honor the aws:RequestedRegion key.
resource "aws_organizations_policy" "deny_non_approved_regions" {
  depends_on  = [aws_organizations_organization.main]
  name        = "deny-non-approved-regions"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Deny API calls in regions not on the approved list."
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyOtherRegions"
      Effect = "Deny"
      NotAction = [
        "iam:*",
        "organizations:*",
        "route53:*",
        "route53domains:*",
        "cloudfront:*",
        "globalaccelerator:*",
        "waf:*",
        "wafv2:*",
        "shield:*",
        "sts:*",
        "support:*",
        "trustedadvisor:*",
        "health:*",
        "tag:*",
        "budgets:*",
        "cur:*",
        "ce:*",
        "pricing:*",
        "ec2:DescribeRegions",
        "ec2:DescribeAvailabilityZones",
        "cloudwatch:*",
        "sso:*",
        "sso-directory:*",
        "identitystore:*",
        "access-analyzer:*",
        "compute-optimizer:*",
        "artifact:*",
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = {
          "aws:RequestedRegion" = var.approved_regions
        }
      }
    }]
  })
}

# 3. Require IMDSv2 on all EC2 instance launches. Closes the SSRF→credential
#    exfil path that hit Capital One. CCSP-relevant, SAA-relevant.
resource "aws_organizations_policy" "require_imdsv2" {
  depends_on  = [aws_organizations_organization.main]
  name        = "require-imdsv2"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Deny ec2:RunInstances if instance metadata is not IMDSv2-only."
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyIMDSv1"
      Effect   = "Deny"
      Action   = "ec2:RunInstances"
      Resource = "arn:aws:ec2:*:*:instance/*"
      Condition = {
        StringNotEquals = {
          "ec2:MetadataHttpTokens" = "required"
        }
      }
    }]
  })
}

# 4. Prevent disabling the audit/security services that the rest of the
#    landing zone depends on. Even AdminAccess principals can't turn these off.
resource "aws_organizations_policy" "deny_disabling_security" {
  depends_on  = [aws_organizations_organization.main]
  name        = "deny-disabling-security-services"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Block disable/delete operations on CloudTrail, Config, GuardDuty, Security Hub."
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyDisable"
      Effect = "Deny"
      Action = [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors",
        "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel",
        "config:StopConfigurationRecorder",
        "config:DeleteConfigurationAggregator",
        "guardduty:DeleteDetector",
        "guardduty:DisassociateFromMasterAccount",
        "guardduty:StopMonitoringMembers",
        "guardduty:UpdateDetector",
        "securityhub:DisableSecurityHub",
        "securityhub:DisassociateFromMasterAccount",
        "securityhub:DeleteInvitations",
      ]
      Resource = "*"
    }]
  })
}

# Attach all four to the Workloads OU.
locals {
  workload_scps = {
    deny_root        = aws_organizations_policy.deny_root.id
    deny_regions     = aws_organizations_policy.deny_non_approved_regions.id
    require_imdsv2   = aws_organizations_policy.require_imdsv2.id
    deny_disable_sec = aws_organizations_policy.deny_disabling_security.id
  }

  security_ou_scps = {
    deny_root        = aws_organizations_policy.deny_root.id
    deny_regions     = aws_organizations_policy.deny_non_approved_regions.id
    deny_disable_sec = aws_organizations_policy.deny_disabling_security.id
  }
}

resource "aws_organizations_policy_attachment" "workloads" {
  for_each  = local.workload_scps
  policy_id = each.value
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "security" {
  for_each  = local.security_ou_scps
  policy_id = each.value
  target_id = aws_organizations_organizational_unit.security.id
}
