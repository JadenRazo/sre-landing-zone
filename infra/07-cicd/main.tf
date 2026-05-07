# GitHub Actions OIDC trust setup.
#
# How this works (the SAA / CCSP-relevant bit):
#   1. GitHub issues a signed JWT to each workflow run, claiming the run's
#      repo, branch, and event.
#   2. AWS IAM trusts the GitHub issuer via the OIDC provider resource.
#   3. The role's trust policy gates `sts:AssumeRoleWithWebIdentity` on:
#        - audience = sts.amazonaws.com (set by aws-actions/configure-aws-credentials)
#        - sub = repo:<org>/<repo>:* (scopes to OUR repo only)
#   4. No long-lived AWS access keys exist anywhere — the workflow gets a
#      ~1-hour STS session each run.

# AWS-side OIDC provider that trusts GitHub Actions tokens.
data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    # GitHub's OIDC thumbprint. AWS recommends you not rely on thumbprint
    # validation for github.com — the IAM service maintains a known list — but
    # we set them explicitly because Terraform requires the field.
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# The Terraform-runner role. Workflows assume this; it has admin in mgmt and
# can chain into member accounts via OrganizationAccountAccessRole.
resource "aws_iam_role" "terraform_runner" {
  name        = "GitHubActionsTerraformRunner"
  description = "Assumed by GitHub Actions workflows across the JadenRazo portfolio repos (sre-*, aws-*, azure-*, multicloud-*). Cross-account chains into OrganizationAccountAccessRole."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Multiple values are OR'd. Forks can't assume because the sub
            # claim is always owner-scoped — `JadenRazo/repo` is set by GitHub
            # based on the repo's owner, not by the workflow file.
            "token.actions.githubusercontent.com:sub" = var.allowed_repo_patterns
          }
        }
      }
    ]
  })

  max_session_duration = 3600 # 1 hour — enough for a long terraform apply
}

# Powers Terraform: full-ish but not root-equivalent.
# AdministratorAccess works for now; tighter scoping is a future hardening.
resource "aws_iam_role_policy_attachment" "terraform_runner_admin" {
  role       = aws_iam_role.terraform_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Inline policy: allow assuming OrganizationAccountAccessRole in ANY org member account.
# Combined with AdministratorAccess in mgmt this means the runner can apply
# every phase's Terraform.
resource "aws_iam_role_policy" "terraform_runner_assume_org" {
  name = "AssumeOrgAccountAccessRoles"
  role = aws_iam_role.terraform_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::*:role/OrganizationAccountAccessRole"
      Condition = {
        # Belt-and-suspenders: only allow assume into accounts in our Org.
        StringEquals = {
          "aws:ResourceOrgID" = "o-9itq8iim1q"
        }
      }
    }]
  })
}
