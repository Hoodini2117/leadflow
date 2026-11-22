output "name" {
  description = "Name of the database Secret."
  value       = kubernetes_secret_v1.database.metadata[0].name
}

output "namespace" {
  description = "Namespace containing the database Secret."
  value       = kubernetes_secret_v1.database.metadata[0].namespace
}
