variable "home_region" {
  description = "Primary AWS region. SAA + cost rationale: us-west-2 is cheaper than us-east-1 with comparable feature parity."
  type        = string
  default     = "us-west-2"
}

variable "secondary_region" {
  description = "Disaster-recovery region (Phase 3). Also where ACM cert for CloudFront must live (Phase 4)."
  type        = string
  default     = "us-east-1"
}

variable "approved_regions" {
  description = "Regions allowed by the DenyNonApprovedRegions SCP. Anything else gets denied at the OU."
  type        = list(string)
  default     = ["us-west-2", "us-east-1"]
}

variable "email_prefix" {
  description = "Prefix for new account emails. Combined with email_domain, e.g. 'jadenscottrazo' + '+aws-log-archive@gmail.com' (Gmail + aliasing). Each account email must be unique across all of AWS, globally."
  type        = string
}

variable "email_domain" {
  description = "Email domain (e.g. gmail.com)."
  type        = string
  default     = "gmail.com"
}

variable "owner_tag" {
  description = "Owner tag value (your handle / email prefix)."
  type        = string
  default     = "jadenrazo"
}

variable "enable_identity_center_resources" {
  description = "Set to true on the SECOND apply, after Identity Center has been enabled in the console (one-click in the management account)."
  type        = bool
  default     = false
}
