terraform {
  required_version = ">= 1.15.3"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.85"
      configuration_aliases = [aws.workloads_dev]
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}
