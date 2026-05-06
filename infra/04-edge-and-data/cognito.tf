# Cognito User Pool: identity provider for a hypothetical /admin route on the
# SRE app. We provision the pool + Hosted UI domain + 1 app client; the actual
# Flask integration (JWT validation middleware) is deferred — but the pool is
# real and the Hosted UI is reachable.
#
# Cost: free up to 50,000 MAU. We'll have 0 MAU in this demo.

resource "aws_cognito_user_pool" "main" {
  provider = aws.workloads_dev
  name     = "sre-users"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  mfa_configuration = "OPTIONAL" # demonstrates MFA setup; user can opt-in via the Hosted UI

  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  auto_verified_attributes = ["email"]

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = true
    developer_only_attribute = false
    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  tags = { Name = "sre-users" }
}

resource "aws_cognito_user_pool_domain" "hosted_ui" {
  provider     = aws.workloads_dev
  domain       = "sre-landing-zone-${local.accounts.workloads_dev}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "web" {
  provider     = aws.workloads_dev
  name         = "sre-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret               = false # PKCE flow; suitable for SPAs
  refresh_token_validity        = 30
  access_token_validity         = 60
  id_token_validity             = 60
  prevent_user_existence_errors = "ENABLED"

  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = var.cognito_callback_urls
  supported_identity_providers         = ["COGNITO"]
}
