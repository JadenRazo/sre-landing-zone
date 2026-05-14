terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.45"
      configuration_aliases = [aws.workloads_dev_primary, aws.workloads_dev_dr]
    }
  }
}
