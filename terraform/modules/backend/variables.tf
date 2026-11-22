variable "namespace" {
  description = "Namespace hosting the backend."
  type        = string
}

variable "config_map_name" {
  description = "ConfigMap providing backend runtime configuration."
  type        = string
}

variable "secret_name" {
  description = "Secret containing DATABASE_URL."
  type        = string
}

variable "image_name" {
  description = "Backend image repository."
  type        = string

  validation {
    condition     = length(trimspace(var.image_name)) > 0
    error_message = "image_name must not be empty."
  }
}

variable "image_tag" {
  description = "Backend image tag."
  type        = string

  validation {
    condition     = length(trimspace(var.image_tag)) > 0
    error_message = "image_tag must not be empty."
  }
}

variable "replicas" {
  description = "Desired backend replicas."
  type        = number

  validation {
    condition     = var.replicas > 0 && var.replicas == floor(var.replicas)
    error_message = "replicas must be a positive integer."
  }
}

variable "container_port" {
  description = "Backend container HTTP port."
  type        = number

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535 && var.container_port == floor(var.container_port)
    error_message = "container_port must be an integer between 1 and 65535."
  }
}

variable "service_port" {
  description = "Backend ClusterIP Service port."
  type        = number

  validation {
    condition     = var.service_port >= 1 && var.service_port <= 65535 && var.service_port == floor(var.service_port)
    error_message = "service_port must be an integer between 1 and 65535."
  }
}

variable "resources" {
  description = "CPU and memory requests and limits for the backend container."
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
    error_message = "All backend resource requests and limits must be non-empty Kubernetes quantities."
  }
}
