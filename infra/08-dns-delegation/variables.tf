variable "home_region" {
  description = "Region for the hosted zone (Route 53 is global, but the resource has to be created from somewhere)."
  type        = string
  default     = "us-west-2"
}

variable "owner_tag" {
  description = "Owner tag value."
  type        = string
  default     = "jadenrazo"
}

variable "subdomain" {
  description = "Subdomain to manage in AWS. Parent stays in your existing DNS provider (Cloudflare). All future projects create records under this."
  type        = string
  default     = "cloud.raizhost.com"
}
