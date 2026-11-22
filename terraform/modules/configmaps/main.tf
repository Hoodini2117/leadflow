resource "kubernetes_config_map_v1" "backend" {
  metadata {
    name      = "backend-config"
    namespace = var.namespace
  }

  data = {
    PORT        = tostring(var.backend_port)
    APP_VERSION = var.app_version
    DB_POOL_MAX = tostring(var.db_pool_max)
  }
}

resource "kubernetes_config_map_v1" "frontend" {
  metadata {
    name      = "frontend-config"
    namespace = var.namespace
  }

  data = {
    NODE_ENV = "production"
    PORT     = tostring(var.frontend_port)
    HOSTNAME = "0.0.0.0"
  }
}

resource "kubernetes_config_map_v1" "postgres" {
  metadata {
    name      = "postgres-config"
    namespace = var.namespace
  }

  data = {
    POSTGRES_DB = var.database_name
    PGDATA      = "/var/lib/postgresql/data/pgdata"
  }
}
