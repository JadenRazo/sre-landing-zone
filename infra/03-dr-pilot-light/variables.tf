variable "primary_region" {
  description = "Active region (where Phase 2 runs)."
  type        = string
  default     = "us-west-2"
}

variable "dr_region" {
  description = "Disaster-recovery region. Must be in approved_regions SCP from Phase 0."
  type        = string
  default     = "us-east-1"
}

variable "owner_tag" {
  description = "Owner tag value."
  type        = string
  default     = "jadenrazo"
}

variable "dr_vpc_cidr" {
  description = "CIDR for DR VPC. Must NOT overlap with primary VPC (10.0.0.0/16)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repo to replicate (matches Phase 2)."
  type        = string
  default     = "sre-reference-app"
}

variable "container_image_tag" {
  description = "Image tag the standby task definition references. After ECR replication runs, the same tag exists in the DR region."
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port the container listens on (matches Phase 2)."
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "CPU units (matches Phase 2)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory MiB (matches Phase 2)."
  type        = number
  default     = 512
}
