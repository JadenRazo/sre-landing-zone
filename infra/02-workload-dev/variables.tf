variable "home_region" {
  description = "Primary region (matches Phases 0 + 1)."
  type        = string
  default     = "us-west-2"
}

variable "owner_tag" {
  description = "Owner tag value."
  type        = string
  default     = "jadenrazo"
}

variable "vpc_cidr" {
  description = "CIDR block for the workloads-dev VPC. Must not overlap with future workloads-prod or DR region VPCs."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to span. 2 = SAA's recommended HA minimum. Each extra AZ adds NAT Gateway cost ($32/mo each) — keep at 2 unless prod-style HA is the goal."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 (1 = no HA; 4+ = no extra AZs in us-west-2)."
  }
}

variable "container_image" {
  description = "Image URI for the ECS task. Default is a public nginx so first-apply works end-to-end. To run the real sre-reference-app: build + push to the ECR repo this stack creates, then set this to its URI."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  description = "Port the container listens on. Default 80 matches nginx; sre-reference-app uses 8080."
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate vCPU allocation (units of 1024 = 1 vCPU). 256 = $0.01/hr."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate memory in MiB. 512 is minimum-viable for nginx."
  type        = number
  default     = 512
}

variable "service_desired_count" {
  description = "Number of running tasks. Set to 0 to keep infra alive but stop paying for tasks."
  type        = number
  default     = 1
}

variable "error_rate" {
  description = "Initial value for the ERROR_RATE secret (sre-reference-app only — ignored by nginx). 0.05 = 5%."
  type        = number
  default     = 0.05
}

variable "log_retention_days" {
  description = "How long to keep CloudWatch task logs. 30 days = SOC2-friendly without runaway storage cost."
  type        = number
  default     = 30
}
