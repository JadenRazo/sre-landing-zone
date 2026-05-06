# Two providers into workloads-dev: home region + us-east-1 (where CloudFront's
# WAF and ACM cert MUST live, regardless of the workload's primary region).

provider "aws" {
  region = var.home_region

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "04-edge-and-data"
      Owner     = var.owner_tag
    }
  }
}

provider "aws" {
  alias  = "workloads_dev"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.workloads_dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase4"
  }

  default_tags {
    tags = {
      Project     = "sre-landing-zone"
      ManagedBy   = "terraform"
      Phase       = "04-edge-and-data"
      Environment = "dev"
      Owner       = var.owner_tag
    }
  }
}

provider "aws" {
  alias  = "workloads_dev_useast1"
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.workloads_dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-phase4-useast1"
  }

  default_tags {
    tags = {
      Project     = "sre-landing-zone"
      ManagedBy   = "terraform"
      Phase       = "04-edge-and-data"
      Environment = "dev"
      Owner       = var.owner_tag
    }
  }
}
