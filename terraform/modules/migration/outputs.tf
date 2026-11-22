output "job_name" {
  description = "Name of the migration Job."
  value       = kubernetes_job_v1.this.metadata[0].name
}

output "job_id" {
  description = "Terraform ID of the migration Job."
  value       = kubernetes_job_v1.this.id
}
