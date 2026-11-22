variable "namespace" {
  description = "Namespace containing the application ConfigMaps."
  type        = string
}

variable "backend_port" {
  description = "Backend HTTP listening port."
  type        = number

  validation {
    condition     = var.backend_port >= 1 && var.backend_port <= 65535 && var.backend_port == floor(var.backend_port)
    error_message = "backend_port must be an integer between 1 and 65535."
  }
}

variable "frontend_port" {
  description = "Frontend HTTP listening port."
  type        = number

  validation {
    condition     = var.frontend_port >= 1 && var.frontend_port <= 65535 && var.frontend_port == floor(var.frontend_port)
    error_message = "frontend_port must be an integer between 1 and 65535."
  }
}

variable "app_version" {
  description = "Version reported by the backend."
  type        = string

  validation {
    condition     = length(trimspace(var.app_version)) > 0
    error_message = "app_version must not be empty."
  }
}

variable "db_pool_max" {
  description = "Maximum PostgreSQL pool size for each backend replica."
  type        = number

  validation {
    condition     = var.db_pool_max >= 1 && var.db_pool_max == floor(var.db_pool_max)
    error_message = "db_pool_max must be a positive integer."
  }
}

variable "database_name" {
  description = "PostgreSQL database created by the official image."
  type        = string

  validation {
    condition     = length(trimspace(var.database_name)) > 0
    error_message = "database_name must not be empty."
  }
}
