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
  description = "GitHub repo name (used in role description). Trust policy uses allowed_repo_patterns for the actual scoping."
  type        = string
  default     = "sre-landing-zone"
}

variable "allowed_repo_patterns" {
  description = "GitHub repo subject patterns allowed to assume this role. StringLike values are OR'd. Forks of any pattern still can't assume because the sub claim is owner-scoped."
  type        = list(string)
  default = [
    "repo:JadenRazo/sre-*:*",        # sre-reference-app, sre-landing-zone (existing)
    "repo:JadenRazo/aws-*:*",        # aws-eks-migration, aws-bedrock-tool, aws-todo-api, etc.
    "repo:JadenRazo/azure-*:*",      # azure-aks-migration, azure-functions-api (cross-cloud projects may use AWS role too)
    "repo:JadenRazo/multicloud-*:*", # multicloud-terraform-platform capstone
  ]
}
