variable "home_region" {
  description = "Primary region (matches Phases 0-6)."
  type        = string
  default     = "us-west-2"
}

variable "owner_tag" {
  description = "Owner tag value."
  type        = string
  default     = "jadenrazo"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repo."
  type        = string
  default     = "JadenRazo"
}

variable "github_repo" {
  description = "GitHub repo name. Trust policy is scoped to repo:<org>/<repo>:* — even a fork can't assume this role with a leaked workflow."
  type        = string
  default     = "sre-landing-zone"
}
