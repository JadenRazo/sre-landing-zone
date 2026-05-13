terraform {
  required_version = ">= 1.15.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.85"
    }
  }
}

provider "aws" {
  region = var.home_region

  default_tags {
    tags = {
      Project     = "sre-landing-zone"
      ManagedBy   = "terraform"
      Phase       = "00-org-bootstrap"
      Owner       = var.owner_tag
      Environment = "shared"
    }
  }
}
