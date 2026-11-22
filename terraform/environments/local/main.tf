module "namespace" {
  source = "../../modules/namespace"
  name   = var.namespace
}

module "secrets" {
  source = "../../modules/secrets"

  namespace         = module.namespace.name
  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
  database_url      = var.database_url
}

module "configmaps" {
  source = "../../modules/configmaps"

  namespace     = module.namespace.name
  backend_port  = var.backend_container_port
  frontend_port = var.frontend_container_port
  app_version   = var.app_version
  db_pool_max   = var.db_pool_max
  database_name = var.database_name
}

module "postgres" {
  source = "../../modules/postgres"

  namespace       = module.namespace.name
  config_map_name = module.configmaps.postgres_name
  secret_name     = module.secrets.name
  image_name      = var.postgres_image_name
  image_tag       = var.postgres_image_tag
  replicas        = var.postgres_replicas
  storage_size    = var.postgres_storage_size
  port            = var.postgres_port
  resources       = var.postgres_resources
}

module "migration" {
  source = "../../modules/migration"

  namespace               = module.namespace.name
  config_map_name         = module.configmaps.backend_name
  secret_name             = module.secrets.name
  image_name              = var.migration_image_name
  image_tag               = var.migration_image_tag
  backoff_limit           = var.migration_backoff_limit
  active_deadline_seconds = var.migration_active_deadline_seconds
  timeout                 = var.migration_timeout
  resources               = var.migration_resources

  depends_on = [module.postgres]
}

module "backend" {
  source = "../../modules/backend"

  namespace       = module.namespace.name
  config_map_name = module.configmaps.backend_name
  secret_name     = module.secrets.name
  image_name      = var.backend_image_name
  image_tag       = var.backend_image_tag
  replicas        = var.backend_replicas
  container_port  = var.backend_container_port
  service_port    = var.backend_service_port
  resources       = var.backend_resources

  depends_on = [module.migration]
}

module "frontend" {
  source = "../../modules/frontend"

  namespace       = module.namespace.name
  config_map_name = module.configmaps.frontend_name
  image_name      = var.frontend_image_name
  image_tag       = var.frontend_image_tag
  replicas        = var.frontend_replicas
  container_port  = var.frontend_container_port
  service_port    = var.frontend_service_port
  resources       = var.frontend_resources

  depends_on = [module.backend]
}

module "networking" {
  source = "../../modules/networking"

  namespace             = module.namespace.name
  ingress_class_name    = var.ingress_class_name
  hostname              = var.ingress_hostname
  frontend_service_name = module.frontend.service_name
  frontend_service_port = module.frontend.service_port
}

