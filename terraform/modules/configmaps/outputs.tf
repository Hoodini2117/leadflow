output "backend_name" {
  description = "Name of the backend ConfigMap."
  value       = kubernetes_config_map_v1.backend.metadata[0].name
}

output "frontend_name" {
  description = "Name of the frontend ConfigMap."
  value       = kubernetes_config_map_v1.frontend.metadata[0].name
}

output "postgres_name" {
  description = "Name of the PostgreSQL ConfigMap."
  value       = kubernetes_config_map_v1.postgres.metadata[0].name
}
