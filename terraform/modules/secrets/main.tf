resource "kubernetes_secret_v1" "database" {
  metadata {
    name      = "leadflow-db-credentials"
    namespace = var.namespace
  }

  type = "Opaque"
  data = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    DATABASE_URL      = var.database_url
  }
}
