# Three providers. The default provider (no alias) targets the management
# account and uses whatever credentials Terraform finds (env, profile, SSO).
# The aliased providers assume `OrganizationAccountAccessRole` in member
# accounts — that role was created automatically by Phase 0 when the accounts
# were provisioned.

provider "aws" {
  region = var.home_region

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "01-security-baseline"
      Owner     = var.owner_tag
    }
  }
}

provider "aws" {
  alias  = "log_archive"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.log_archive}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase1"
  }

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "01-security-baseline"
      Owner     = var.owner_tag
    }
  }
}

provider "aws" {
  alias  = "audit_security"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.audit_security}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase1"
  }

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "01-security-baseline"
      Owner     = var.owner_tag
    }
  }
}
