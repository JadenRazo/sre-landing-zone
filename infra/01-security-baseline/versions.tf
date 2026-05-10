terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.100"
      configuration_aliases = [aws.log_archive, aws.audit_security]
    }
  }
}
