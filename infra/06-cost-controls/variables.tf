variable "home_region" {
  description = "Primary region (matches Phases 0–2)."
  type        = string
  default     = "us-west-2"
}

variable "owner_tag" {
  description = "Owner tag value."
  type        = string
  default     = "jadenrazo"
}

variable "auto_stop_cron" {
  description = "EventBridge cron for the daily auto-stop. Default: 8 PM PST = 04:00 UTC."
  type        = string
  default     = "cron(0 4 * * ? *)"
}

variable "auto_stop_cluster_name" {
  description = "ECS cluster the Lambda should scale to 0 (matches Phase 2)."
  type        = string
  default     = "sre-workloads-dev"
}

variable "auto_stop_service_name" {
  description = "ECS service the Lambda should scale to 0 (matches Phase 2)."
  type        = string
  default     = "sre-reference-app"
}

variable "anomaly_threshold_usd" {
  description = "Dollar threshold above which Cost Anomaly Detection fires an alert."
  type        = number
  default     = 5
}

variable "alert_email" {
  description = "Email for cost anomaly alerts (in addition to the Phase 1 SNS topic). Subscribe + confirm after first apply."
  type        = string
}
