resource "kubernetes_stateful_set" "onify-worker" {
  metadata {
    name      = "onify-worker"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "onify-worker"
      name = "onify-worker"
    }
  }
  spec {
    service_name = "onify-worker"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "onify-worker"
        task = "onify-worker"
      }
    }
    template {
      metadata {
        labels = {
          app  = "onify-worker"
          task = "onify-worker"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/api:${var.onify-worker_version}"
          name  = "onify-worker"
          port {
            name           = "onify-worker"
            container_port = 8181
          }
          args = ["worker"]
          dynamic "env" {
            for_each = var.onify_default_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env" {
            for_each = var.onify_api_worker_defaults
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env" {
            for_each = var.onify_worker_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env" {
            for_each = var.onify_api_envs
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}
