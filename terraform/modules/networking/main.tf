resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = "leadflow"
    namespace = var.namespace
  }

  spec {
    ingress_class_name = var.ingress_class_name

    rule {
      host = var.hostname == "" ? null : var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = var.frontend_service_name

              port {
                number = var.frontend_service_port
              }
            }
          }
        }
      }
    }
  }
}
