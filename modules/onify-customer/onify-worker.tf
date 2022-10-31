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
          image = "eu.gcr.io/onify-images/hub/api:${var.onify-worker_version}"
          name  = "onify-worker"
          resources {
            limits = {
              cpu    = var.onify-worker_cpu_limit
              memory = var.onify-worker_memory_limit
            }
            requests = {
              cpu    = var.onify-worker_cpu_requests
              memory = var.onify-worker_memory_requests
            }
          }
          port {
            name           = "onify-worker"
            container_port = 8181
          }
          args = ["worker"]
          dynamic "env" {
            for_each = var.onify_worker_envs
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
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}