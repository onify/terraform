resource "kubernetes_stateful_set" "onify-worker" {
  metadata {
    name      = "${local.namespace}-worker"
    namespace = local.workload_namespace
    labels = {
      app  = "${local.namespace}-worker"
      name = "${local.namespace}-worker"
    }
  }
  spec {
    service_name = "${local.namespace}-worker"
    replicas     = var.worker_replicas
    selector {
      match_labels = {
        app  = "${local.namespace}-worker"
        task = "${local.namespace}-worker"
      }
    }
    template {
      metadata {
        annotations = {
          "checksum/api-config" = sha256(jsonencode(kubernetes_config_map.onify-api.data))
        }
        labels = {
          app  = "${local.namespace}-worker"
          task = "${local.namespace}-worker"
        }
      }
      spec {
        dynamic "image_pull_secrets" {
          for_each = kubernetes_secret.registry
          content {
            name = image_pull_secrets.value.metadata[0].name
          }
        }

        container {
          image             = var.onify_worker_image
          image_pull_policy = var.image_pull_policy
          name              = "onify-worker"
          port {
            name           = "worker"
            container_port = 8181
          }
          args = ["worker"]
          dynamic "env" {
            for_each = local.api_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env_from" {
            for_each = local.api_runtime_secrets
            content {
              secret_ref { name = env_from.value }
            }
          }
          env_from {
            config_map_ref {
              name = "${local.namespace}-api"
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}
