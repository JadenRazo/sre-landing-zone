provider "aws" {
  region = var.home_region

  default_tags {
    tags = {
      Project   = "sre-landing-zone"
      ManagedBy = "terraform"
      Phase     = "07-cicd"
      Owner     = var.owner_tag
    }
  }
}
