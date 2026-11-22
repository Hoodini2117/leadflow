resource "kubernetes_job_v1" "this" {
  metadata {
    name      = "leadflow-migrate"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"    = "migration"
      "app.kubernetes.io/part-of" = "leadflow"
    }
  }

  wait_for_completion = true

  spec {
    backoff_limit           = var.backoff_limit
  #  active_deadline_seconds = var.active_deadline_seconds
    completions             = 1
    parallelism             = 1

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "migration"
          "app.kubernetes.io/part-of" = "leadflow"
        }
      }

      spec {
        restart_policy                  = "Never"
        automount_service_account_token = false
        enable_service_links            = false

        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "migration"
          image             = "${var.image_name}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"
          command           = ["node", "dist/migrate.js"]

          env_from {
            config_map_ref {
              name = var.config_map_name
            }
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "DATABASE_URL"
              }
            }
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
        }
      }
    }
  }

  timeouts {
    create = var.timeout
    update = var.timeout
  }

  lifecycle {
    # Kubernetes generates this immutable selector for non-manual Jobs.
    ignore_changes = [spec[0].selector]
  }
}
