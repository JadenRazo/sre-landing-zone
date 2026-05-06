variable "home_region" {
  description = "Primary region (matches Phase 0)."
  type        = string
  default     = "us-west-2"
}

variable "owner_tag" {
  description = "Owner tag value."
  type        = string
  default     = "jadenrazo"
}

variable "alert_email" {
  description = "Email to receive Budgets + Security Hub findings notifications. Subscribe and click confirm in your inbox after first apply."
  type        = string
}

variable "budget_thresholds_usd" {
  description = "Dollar thresholds at which to fire forecasted-overspend alerts. Mirrors the project's $120 credit cap."
  type        = list(number)
  default     = [20, 50, 80, 100]
}

variable "config_recording_frequency" {
  description = "AWS Config recording frequency. CONTINUOUS is more accurate but costs more; DAILY is fine for cert-prep volumes."
  type        = string
  default     = "DAILY"

  validation {
    condition     = contains(["CONTINUOUS", "DAILY"], var.config_recording_frequency)
    error_message = "Must be CONTINUOUS or DAILY."
  }
}

variable "guardduty_finding_publishing_frequency" {
  description = "How often GuardDuty exports findings. SIX_HOURS is the cheapest sane default; FIFTEEN_MINUTES for active investigations."
  type        = string
  default     = "SIX_HOURS"
}
