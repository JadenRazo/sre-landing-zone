terraform {
  required_version = ">= 1.15.3"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.85"
      configuration_aliases = [aws.workloads_dev_primary, aws.workloads_dev_dr]
    }
  }
}
