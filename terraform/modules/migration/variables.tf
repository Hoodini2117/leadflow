variable "namespace" {
  description = "Namespace in which the migration Job runs."
  type        = string
}

variable "config_map_name" {
  description = "Backend ConfigMap supplying non-sensitive migration settings."
  type        = string
}

variable "secret_name" {
  description = "Secret containing DATABASE_URL."
  type        = string
}

variable "image_name" {
  description = "Image repository containing the compiled migration program."
  type        = string

  validation {
    condition     = length(trimspace(var.image_name)) > 0
    error_message = "image_name must not be empty."
  }
}

variable "image_tag" {
  description = "Migration image tag."
  type        = string

  validation {
    condition     = length(trimspace(var.image_tag)) > 0
    error_message = "image_tag must not be empty."
  }
}

variable "backoff_limit" {
  description = "Maximum failed Job retries before Kubernetes marks it failed."
  type        = number
  default     = 3

  validation {
    condition     = var.backoff_limit >= 0 && var.backoff_limit == floor(var.backoff_limit)
    error_message = "backoff_limit must be a non-negative integer."
  }
}

variable "active_deadline_seconds" {
  description = "Maximum duration of the migration Job."
  type        = number
  default     = 300

  validation {
    condition     = var.active_deadline_seconds > 0 && var.active_deadline_seconds == floor(var.active_deadline_seconds)
    error_message = "active_deadline_seconds must be a positive integer."
  }
}

variable "timeout" {
  description = "Terraform wait timeout for Job creation and completion."
  type        = string
  default     = "10m"
}

variable "resources" {
  description = "CPU and memory requests and limits for the migration container."
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })

  validation {
    condition = alltrue([
      for quantity in [
        var.resources.requests.cpu,
        var.resources.requests.memory,
        var.resources.limits.cpu,
        var.resources.limits.memory
      ] : length(trimspace(quantity)) > 0
    ])
    error_message = "All migration resource requests and limits must be non-empty Kubernetes quantities."
  }
}
