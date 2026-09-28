resource "kubernetes_stateful_set" "onify-worker" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-worker"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-worker"
      name = "${local.client_code}-${local.onify_instance}-worker"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-worker"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-worker"
        task = "${local.client_code}-${local.onify_instance}-worker"
      }
    }
    template {
      metadata {
        annotations = {
          "checksum/api-config" = sha256(jsonencode(kubernetes_config_map.onify-api.data))
        }
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-worker"
          task = "${local.client_code}-${local.onify_instance}-worker"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image             = coalesce(var.onify_worker_image, var.onify_api_image)
          image_pull_policy = "Always"
          name              = "onify-worker"
          port {
            name           = "worker"
            container_port = 8181
          }
          args = ["worker"]
          dynamic "env" {
            for_each = var.onify_api_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env_from {
            config_map_ref {
              name = "${local.client_code}-${local.onify_instance}-api"
            }
          }
          dynamic "resources" {
            for_each = var.onify_worker_memory_limit != null || var.onify_worker_cpu_limit != null || var.onify_worker_memory_requests != null || var.onify_worker_cpu_requests != null ? [1] : []
            content {
              limits = var.onify_worker_memory_limit != null || var.onify_worker_cpu_limit != null ? {
                memory = var.onify_worker_memory_limit
                cpu    = var.onify_worker_cpu_limit
              } : {}
              requests = var.onify_worker_memory_requests != null || var.onify_worker_cpu_requests != null ? {
                memory = var.onify_worker_memory_requests
                cpu    = var.onify_worker_cpu_requests
              } : {}
            }
          }
        }
        node_name = var.kubernetes_node_api_worker != null ? var.kubernetes_node_api_worker : null
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}
