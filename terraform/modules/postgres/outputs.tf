output "deployment_name" {
  description = "Name of the PostgreSQL Deployment."
  value       = kubernetes_deployment_v1.database.metadata[0].name
}

output "service_name" {
  description = "Name of the PostgreSQL Service."
  value       = kubernetes_service_v1.database.metadata[0].name
}

output "service_cluster_ip" {
  description = "Cluster IP assigned to the PostgreSQL Service."
  value       = kubernetes_service_v1.database.spec[0].cluster_ip
}

output "service_port" {
  description = "Port exposed by the PostgreSQL Service."
  value       = var.port
}

output "pvc_name" {
  description = "Name of the persistent volume claim."
  value       = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
}
