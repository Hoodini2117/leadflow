output "deployment_name" {
  description = "Name of the backend Deployment."
  value       = kubernetes_deployment_v1.this.metadata[0].name
}

output "service_name" {
  description = "Name of the backend Service."
  value       = kubernetes_service_v1.this.metadata[0].name
}

output "service_cluster_ip" {
  description = "Cluster IP assigned to the backend Service."
  value       = kubernetes_service_v1.this.spec[0].cluster_ip
}

output "service_port" {
  description = "Port exposed by the backend Service."
  value       = var.service_port
}
