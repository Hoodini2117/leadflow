variable "namespace" {
  description = "Namespace containing the database Secret."
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL application user."
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
  description = "PostgreSQL connection string used by the backend and migration Job."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^postgres(ql)?://", trimspace(var.database_url)))
    error_message = "database_url must use a postgres:// or postgresql:// URL."
  }
}
