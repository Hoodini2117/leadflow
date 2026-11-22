variable "name" {
  description = "Namespace for all LeadFlow resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) <= 63
    error_message = "name must be a valid Kubernetes namespace name of at most 63 characters."
  }
}
