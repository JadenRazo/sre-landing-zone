variable "home_region" {
  description = "Primary region (matches Phase 2)."
  type        = string
  default     = "us-west-2"
}

variable "owner_tag" {
  description = "Owner tag value."
  type        = string
  default     = "jadenrazo"
}

variable "rate_limit_per_5min" {
  description = "WAF rate limit per IP per 5-minute window."
  type        = number
  default     = 1000
}

variable "geo_allowed_countries" {
  description = "ISO country codes allowed by CloudFront geo-restriction. Empty list disables the restriction."
  type        = list(string)
  default     = ["US", "CA", "MX", "GB"] # demo: NA + UK
}

variable "cognito_callback_urls" {
  description = "OAuth callback URLs for the Cognito app client. Initial value is a placeholder for the demo."
  type        = list(string)
  default     = ["https://example.com/callback"]
}
