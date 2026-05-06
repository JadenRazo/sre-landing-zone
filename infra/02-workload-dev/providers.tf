# Default provider = management account (where this stack runs from).
# We use it only to read the SSM account map. All actual workload resources
# go through the aws.workloads_dev alias.
provider "aws" {
  region = var.home_region

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "02-workload-dev"
      Owner     = var.owner_tag
    }
  }
}

provider "aws" {
  alias  = "workloads_dev"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.workloads_dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase2"
  }

  default_tags {
    tags = {
      Project     = "sre-landing-zone"
      ManagedBy   = "terraform"
      Phase       = "02-workload-dev"
      Environment = "dev"
      Owner       = var.owner_tag
    }
  }
}
