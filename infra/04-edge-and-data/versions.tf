terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.85"
      configuration_aliases = [aws.workloads_dev, aws.workloads_dev_useast1]
    }
  }
}
