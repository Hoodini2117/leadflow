variable "namespace" {
  description = "Namespace hosting PostgreSQL."
  type        = string
}

variable "config_map_name" {
  description = "PostgreSQL ConfigMap name."
  type        = string
}

variable "secret_name" {
  description = "Secret containing the database username and password."
  type        = string
}

variable "image_name" {
  description = "PostgreSQL image repository."
  type        = string

  validation {
    condition     = length(trimspace(var.image_name)) > 0
    error_message = "image_name must not be empty."
  }
}

variable "image_tag" {
  description = "PostgreSQL image tag."
  type        = string

  validation {
    condition     = length(trimspace(var.image_tag)) > 0
    error_message = "image_tag must not be empty."
  }
}

variable "replicas" {
  description = "PostgreSQL replicas. This single-PVC deployment supports exactly one."
  type        = number

  validation {
    condition     = var.replicas == 1
    error_message = "PostgreSQL replicas must remain 1 while using a single ReadWriteOnce PVC."
  }
}

variable "storage_size" {
  description = "Persistent volume claim storage request."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*(Ki|Mi|Gi|Ti|K|M|G|T)?$", var.storage_size))
    error_message = "storage_size must be a positive Kubernetes storage quantity such as 5Gi."
  }
}

variable "port" {
  description = "PostgreSQL TCP port."
  type        = number

  validation {
    condition     = var.port >= 1 && var.port <= 65535 && var.port == floor(var.port)
    error_message = "port must be an integer between 1 and 65535."
  }
}

variable "resources" {
  description = "CPU and memory requests and limits for PostgreSQL."
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
    error_message = "All PostgreSQL resource requests and limits must be non-empty Kubernetes quantities."
  }
}
