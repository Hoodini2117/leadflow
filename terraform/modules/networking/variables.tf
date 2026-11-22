variable "namespace" {
  description = "Namespace containing the Ingress."
  type        = string
}

variable "ingress_class_name" {
  description = "Ingress controller class."
  type        = string

  validation {
    condition     = length(trimspace(var.ingress_class_name)) > 0
    error_message = "ingress_class_name must not be empty."
  }
}

variable "hostname" {
  description = "Optional DNS hostname. Empty means the Ingress matches any host."
  type        = string
  default     = ""

  validation {
    condition     = var.hostname == "" || can(regex("^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$", var.hostname))
    error_message = "hostname must be empty or a valid DNS hostname."
  }
}

variable "frontend_service_name" {
  description = "Frontend Service receiving ingress traffic."
  type        = string
}

variable "frontend_service_port" {
  description = "Frontend Service port receiving ingress traffic."
  type        = number

  validation {
    condition     = var.frontend_service_port >= 1 && var.frontend_service_port <= 65535 && var.frontend_service_port == floor(var.frontend_service_port)
    error_message = "frontend_service_port must be an integer between 1 and 65535."
  }
}
