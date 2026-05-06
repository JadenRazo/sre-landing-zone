# Three providers:
#   default              → mgmt account, primary region (Route 53 health checks live here)
#   aws.workloads_dev_primary → workloads-dev account, primary region (us-west-2)
#   aws.workloads_dev_dr     → workloads-dev account, DR region (us-east-1)

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "03-dr-pilot-light"
      Owner     = var.owner_tag
    }
  }
}

provider "aws" {
  alias  = "workloads_dev_primary"
  region = var.primary_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.workloads_dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase3-primary"
  }

  default_tags {
    tags = {
      Project     = "sre-landing-zone"
      ManagedBy   = "terraform"
      Phase       = "03-dr-pilot-light"
      Environment = "dev"
      Owner       = var.owner_tag
      DRRole      = "primary"
    }
  }
}

provider "aws" {
  alias  = "workloads_dev_dr"
  region = var.dr_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.workloads_dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase3-dr"
  }

  default_tags {
    tags = {
      Project     = "sre-landing-zone"
      ManagedBy   = "terraform"
      Phase       = "03-dr-pilot-light"
      Environment = "dev"
      Owner       = var.owner_tag
      DRRole      = "standby"
    }
  }
}
