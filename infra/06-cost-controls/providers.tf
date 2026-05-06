provider "aws" {
  region = var.home_region

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "06-cost-controls"
      Owner     = var.owner_tag
    }
  }
}

provider "aws" {
  alias  = "workloads_dev"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.workloads_dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase6"
  }

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "06-cost-controls"
      Owner     = var.owner_tag
    }
  }
}
