# AWS Secrets Manager: holds the ERROR_RATE configuration the sre-reference-app
# reads at boot. Demonstrates the pattern of using Secrets Manager (not env vars)
# for runtime configuration that may rotate.
#
# Why this matters for cert prep:
#  - SAA Domain 1 (Secure): KMS-encrypted at rest, IAM-scoped read access
#  - CCSP: rotation, least-privilege access, separation of secret from code
#
# Cost: $0.40/secret/month + $0.05 per 10,000 API calls. One secret here = $0.40/mo.

# Customer-managed KMS key for the secret. AWS-managed key (alias/aws/secretsmanager)
# is free; using a CMK ($1/mo) demonstrates the pattern but isn't strictly needed.
# Sticking with the AWS-managed key here to save the dollar.

resource "aws_secretsmanager_secret" "error_rate" {
  provider                = aws.workloads_dev
  name                    = "sre-reference-app/error-rate"
  description             = "Synthetic error injection rate for the SRE reference app. 0.0 = no errors, 1.0 = always 500."
  recovery_window_in_days = 7 # cooling-off period if you accidentally delete

  tags = { Name = "sre-error-rate" }
}

resource "aws_secretsmanager_secret_version" "error_rate" {
  provider      = aws.workloads_dev
  secret_id     = aws_secretsmanager_secret.error_rate.id
  secret_string = jsonencode({ ERROR_RATE = tostring(var.error_rate) })
}
