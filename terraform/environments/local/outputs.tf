output "namespace" {
  description = "Namespace hosting the LeadFlow stack."
  value       = module.namespace.name
}

output "services" {
  description = "Service names, ClusterIPs, and ports."
  value = {
    postgres = {
      name       = module.postgres.service_name
      cluster_ip = module.postgres.service_cluster_ip
      port       = module.postgres.service_port
    }
    backend = {
      name       = module.backend.service_name
      cluster_ip = module.backend.service_cluster_ip
      port       = module.backend.service_port
    }
    frontend = {
      name       = module.frontend.service_name
      cluster_ip = module.frontend.service_cluster_ip
      port       = module.frontend.service_port
    }
  }
}

output "deployments" {
  description = "Managed Deployment names."
  value = {
    postgres = module.postgres.deployment_name
    backend  = module.backend.deployment_name
    frontend = module.frontend.deployment_name
  }
}

output "migration_job" {
  description = "Migration Job name."
  value       = module.migration.job_name
}

output "postgres_pvc" {
  description = "PostgreSQL persistent volume claim name."
  value       = module.postgres.pvc_name
}

output "ingress" {
  description = "Ingress resource configuration."
  value = {
    name        = module.networking.ingress_name
    class       = module.networking.ingress_class_name
    hostname    = module.networking.hostname
    frontend    = module.frontend.service_name
    servicePort = module.frontend.service_port
  }
}
