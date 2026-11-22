output "ingress_name" {
  description = "Name of the Ingress resource."
  value       = kubernetes_ingress_v1.this.metadata[0].name
}

output "ingress_class_name" {
  description = "Ingress controller class."
  value       = var.ingress_class_name
}

output "hostname" {
  description = "Configured hostname, or empty when no host rule is configured."
  value       = var.hostname
}
