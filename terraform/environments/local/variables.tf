variable "kubeconfig_path" {
  description = "Path to the kubeconfig containing the existing Kind cluster."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubeconfig context for the local Kind cluster."
  type        = string
  default     = "kind-leadflow"
}

variable "namespace" {
  description = "Namespace for LeadFlow."
  type        = string
  default     = "leadflow"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "namespace must be a valid Kubernetes namespace name of at most 63 characters."
  }
}

variable "postgres_user" {
  description = "PostgreSQL application username."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.postgres_user)) > 0
    error_message = "postgres_user must not be empty."
  }
}

variable "postgres_password" {
  description = "PostgreSQL application password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.postgres_password)) > 0
    error_message = "postgres_password must not be empty."
  }
}

variable "database_url" {
  description = "PostgreSQL URL used by the backend and migration Job; point it at postgres:5432."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^postgres(ql)?://", trimspace(var.database_url)))
    error_message = "database_url must use a postgres:// or postgresql:// URL."
  }
}

variable "database_name" {
  description = "Database created by the PostgreSQL image."
  type        = string
  default     = "leadflow"

  validation {
    condition     = length(trimspace(var.database_name)) > 0
    error_message = "database_name must not be empty."
  }
}

variable "app_version" {
  description = "Version reported by the backend /version endpoint."
  type        = string
  default     = "1.0.0"

  validation {
    condition     = length(trimspace(var.app_version)) > 0
    error_message = "app_version must not be empty."
  }
}

variable "db_pool_max" {
  description = "Maximum PostgreSQL pool size for each backend replica."
  type        = number
  default     = 10

  validation {
    condition     = var.db_pool_max >= 1 && var.db_pool_max == floor(var.db_pool_max)
    error_message = "db_pool_max must be a positive integer."
  }
}

variable "postgres_replicas" {
  description = "PostgreSQL replicas. The current single ReadWriteOnce PVC design is single-replica."
  type        = number
  default     = 1

  validation {
    condition     = var.postgres_replicas == 1
    error_message = "postgres_replicas must remain 1 until PostgreSQL uses a replicated storage/HA design."
  }
}

variable "backend_replicas" {
  description = "Desired backend Deployment replicas."
  type        = number
  default     = 2

  validation {
    condition     = var.backend_replicas > 0 && var.backend_replicas == floor(var.backend_replicas)
    error_message = "backend_replicas must be a positive integer."
  }
}

variable "frontend_replicas" {
  description = "Desired frontend Deployment replicas."
  type        = number
  default     = 2

  validation {
    condition     = var.frontend_replicas > 0 && var.frontend_replicas == floor(var.frontend_replicas)
    error_message = "frontend_replicas must be a positive integer."
  }
}

variable "postgres_storage_size" {
  description = "PostgreSQL PVC storage request."
  type        = string
  default     = "5Gi"

  validation {
    condition     = can(regex("^[1-9][0-9]*(Ki|Mi|Gi|Ti|K|M|G|T)?$", var.postgres_storage_size))
    error_message = "postgres_storage_size must be a positive Kubernetes quantity such as 5Gi."
  }
}

variable "postgres_image_name" {
  description = "PostgreSQL image repository."
  type        = string
  default     = "postgres"

  validation {
    condition     = length(trimspace(var.postgres_image_name)) > 0
    error_message = "postgres_image_name must not be empty."
  }
}

variable "postgres_image_tag" {
  description = "PostgreSQL image tag."
  type        = string
  default     = "16"

  validation {
    condition     = length(trimspace(var.postgres_image_tag)) > 0
    error_message = "postgres_image_tag must not be empty."
  }
}

variable "migration_image_name" {
  description = "Image repository containing the compiled database migration program."
  type        = string
  default     = "leadflow-migrate"

  validation {
    condition     = length(trimspace(var.migration_image_name)) > 0
    error_message = "migration_image_name must not be empty."
  }
}

variable "migration_image_tag" {
  description = "Migration image tag."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.migration_image_tag)) > 0
    error_message = "migration_image_tag must not be empty."
  }
}

variable "migration_backoff_limit" {
  description = "Maximum failed Job retries before Kubernetes marks the migration Job failed."
  type        = number
  default     = 3

  validation {
    condition     = var.migration_backoff_limit >= 0 && var.migration_backoff_limit == floor(var.migration_backoff_limit)
    error_message = "migration_backoff_limit must be a non-negative integer."
  }
}

variable "migration_active_deadline_seconds" {
  description = "Maximum runtime for the migration Job."
  type        = number
  default     = 300

  validation {
    condition     = var.migration_active_deadline_seconds > 0 && var.migration_active_deadline_seconds == floor(var.migration_active_deadline_seconds)
    error_message = "migration_active_deadline_seconds must be a positive integer."
  }
}

variable "migration_timeout" {
  description = "Terraform wait timeout for migration Job completion."
  type        = string
  default     = "10m"

  validation {
    condition     = can(regex("^[1-9][0-9]*(s|m|h)$", var.migration_timeout))
    error_message = "migration_timeout must be a positive duration such as 30s or 10m."
  }
}

variable "backend_image_name" {
  description = "Backend image repository."
  type        = string
  default     = "leadflow-backend"

  validation {
    condition     = length(trimspace(var.backend_image_name)) > 0
    error_message = "backend_image_name must not be empty."
  }
}

variable "backend_image_tag" {
  description = "Backend image tag."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.backend_image_tag)) > 0
    error_message = "backend_image_tag must not be empty."
  }
}

variable "frontend_image_name" {
  description = "Frontend image repository."
  type        = string
  default     = "leadflow-frontend"

  validation {
    condition     = length(trimspace(var.frontend_image_name)) > 0
    error_message = "frontend_image_name must not be empty."
  }
}

variable "frontend_image_tag" {
  description = "Frontend image tag."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.frontend_image_tag)) > 0
    error_message = "frontend_image_tag must not be empty."
  }
}

variable "postgres_port" {
  description = "PostgreSQL Service and container port."
  type        = number
  default     = 5432

  validation {
    condition     = var.postgres_port >= 1 && var.postgres_port <= 65535 && var.postgres_port == floor(var.postgres_port)
    error_message = "postgres_port must be an integer between 1 and 65535."
  }
}

variable "backend_container_port" {
  description = "Backend container listening port."
  type        = number
  default     = 3000

  validation {
    condition     = var.backend_container_port >= 1 && var.backend_container_port <= 65535 && var.backend_container_port == floor(var.backend_container_port)
    error_message = "backend_container_port must be an integer between 1 and 65535."
  }
}

variable "backend_service_port" {
  description = "Backend Service port."
  type        = number
  default     = 3000

  validation {
    condition     = var.backend_service_port >= 1 && var.backend_service_port <= 65535 && var.backend_service_port == floor(var.backend_service_port)
    error_message = "backend_service_port must be an integer between 1 and 65535."
  }
}

variable "frontend_container_port" {
  description = "Frontend container listening port."
  type        = number
  default     = 3000

  validation {
    condition     = var.frontend_container_port >= 1 && var.frontend_container_port <= 65535 && var.frontend_container_port == floor(var.frontend_container_port)
    error_message = "frontend_container_port must be an integer between 1 and 65535."
  }
}

variable "frontend_service_port" {
  description = "Frontend Service port."
  type        = number
  default     = 80

  validation {
    condition     = var.frontend_service_port >= 1 && var.frontend_service_port <= 65535 && var.frontend_service_port == floor(var.frontend_service_port)
    error_message = "frontend_service_port must be an integer between 1 and 65535."
  }
}

variable "postgres_resources" {
  description = "PostgreSQL main container CPU and memory requests/limits."
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "250m", memory = "256Mi" }
    limits   = { cpu = "1", memory = "1Gi" }
  }
}

variable "migration_resources" {
  description = "Migration container CPU and memory requests/limits."
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "100m", memory = "128Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "backend_resources" {
  description = "Backend container CPU and memory requests/limits."
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "100m", memory = "128Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "frontend_resources" {
  description = "Frontend container CPU and memory requests/limits."
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "ingress_class_name" {
  description = "Ingress controller class."
  type        = string
  default     = "nginx"

  validation {
    condition     = length(trimspace(var.ingress_class_name)) > 0
    error_message = "ingress_class_name must not be empty."
  }
}

variable "ingress_hostname" {
  description = "Optional DNS hostname. Leave empty to match any host, as in the current Kind manifest."
  type        = string
  default     = ""

  validation {
    condition     = var.ingress_hostname == "" || can(regex("^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$", var.ingress_hostname))
    error_message = "ingress_hostname must be empty or a valid DNS hostname."
  }
}
