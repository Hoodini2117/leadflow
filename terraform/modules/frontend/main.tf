resource "kubernetes_deployment_v1" "this" {
  wait_for_rollout = true

  metadata {
    name      = "frontend"
    namespace = var.namespace
  }

  spec {
    replicas                  = var.replicas
    revision_history_limit    = 5
    progress_deadline_seconds = 600

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "frontend"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "frontend"
          "app.kubernetes.io/part-of" = "leadflow"
        }
      }

      spec {
        automount_service_account_token  = false
        enable_service_links             = false
        termination_grace_period_seconds = 30

        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "frontend"
          image             = "${var.image_name}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          env_from {
            config_map_ref {
              name = var.config_map_name
            }
          }

          port {
            name           = "http"
            container_port = var.container_port
            protocol       = "TCP"
          }

          startup_probe {
            http_get {
              path   = "/"
              port   = "http"
              scheme = "HTTP"
            }
            period_seconds    = 5
            timeout_seconds   = 3
            failure_threshold = 18
          }

          liveness_probe {
            http_get {
              path   = "/"
              port   = "http"
              scheme = "HTTP"
            }
            period_seconds    = 20
            timeout_seconds   = 3
            failure_threshold = 3
          }

          readiness_probe {
            http_get {
              path   = "/"
              port   = "http"
              scheme = "HTTP"
            }
            period_seconds    = 5
            timeout_seconds   = 3
            failure_threshold = 3
          }

          resources {
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
          }

          security_context {
            run_as_non_root            = true
            run_as_user                = 1000
            run_as_group               = 1000
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "next-cache"
            mount_path = "/app/.next/cache"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "next-cache"
          empty_dir {}
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }

  timeouts {
    create = "10m"
    update = "10m"
  }
}

resource "kubernetes_service_v1" "this" {
  wait_for_load_balancer = false

  depends_on = [kubernetes_deployment_v1.this]

  metadata {
    name      = "frontend"
    namespace = var.namespace
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "frontend"
    }

    port {
      name        = "http"
      port        = var.service_port
      target_port = "http"
      protocol    = "TCP"
    }
  }
}
