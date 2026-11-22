resource "kubernetes_persistent_volume_claim_v1" "data" {
  # With WaitForFirstConsumer, binding requires a scheduled pod. Do not make
  # Terraform wait for Bound before it can create the Deployment that consumes it.
  wait_until_bound = false

  metadata {
    name      = "postgres-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment_v1" "database" {
  wait_for_rollout = true

  metadata {
    name      = "postgres"
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "postgres"
          "app.kubernetes.io/part-of" = "leadflow"
        }
      }

      spec {
        automount_service_account_token = false
        enable_service_links            = false

        security_context {
          fs_group               = 999
          fs_group_change_policy = "OnRootMismatch"

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        init_container {
          name              = "prepare-data-directory"
          image             = "${var.image_name}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-ec", "mkdir -p /var/lib/postgresql/data/pgdata && chown 999:999 /var/lib/postgresql/data /var/lib/postgresql/data/pgdata"]

          security_context {
            run_as_user                = 0
            run_as_group               = 0
            run_as_non_root            = false
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
              add  = ["CHOWN"]
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "16Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        container {
          name              = "postgres"
          image             = "${var.image_name}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          env {
            name = "POSTGRES_DB"
            value_from {
              config_map_key_ref {
                name = var.config_map_name
                key  = "POSTGRES_DB"
              }
            }
          }

          env {
            name = "PGDATA"
            value_from {
              config_map_key_ref {
                name = var.config_map_name
                key  = "PGDATA"
              }
            }
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          port {
            name           = "postgres"
            container_port = var.port
            protocol       = "TCP"
          }

          startup_probe {
            exec {
              command = ["sh", "-ec", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 30
          }

          liveness_probe {
            exec {
              command = ["sh", "-ec", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
            }
            period_seconds    = 20
            timeout_seconds   = 5
            failure_threshold = 3
          }

          readiness_probe {
            exec {
              command = ["sh", "-ec", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
            }
            period_seconds    = 10
            timeout_seconds   = 5
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
            run_as_user                = 999
            run_as_group               = 999
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          volume_mount {
            name       = "postgres-run"
            mount_path = "/var/run/postgresql"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "postgres-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
          }
        }

        volume {
          name = "postgres-run"
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

resource "kubernetes_service_v1" "database" {
  wait_for_load_balancer = false

  depends_on = [kubernetes_deployment_v1.database]

  metadata {
    name      = "postgres"
    namespace = var.namespace
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "postgres"
    }

    port {
      name        = "postgres"
      port        = var.port
      target_port = "postgres"
      protocol    = "TCP"
    }
  }
}
