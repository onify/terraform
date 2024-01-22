resource "kubernetes_stateful_set" "onify-hub-worker" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-worker"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-hub-worker"
      name = "${local.client_code}-${local.onify_instance}-hub-worker"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-hub-worker"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-hub-worker"
        task = "${local.client_code}-${local.onify_instance}-hub-worker"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-hub-worker"
          task = "${local.client_code}-${local.onify_instance}-hub-worker"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.onify_hub_worker_image
          name  = "onify-hub-worker"
          port {
            name           = "hub-worker"
            container_port = 8181
          }
          args = ["worker"]
          dynamic "env" {
            for_each = var.onify_hub_api_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env_from {
            config_map_ref {
              name = "${local.client_code}-${local.onify_instance}-hub-api"
            }
          }
        }
        node_name = var.kubernetes_node_api_worker != null ? var.kubernetes_node_api_worker : null
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}
