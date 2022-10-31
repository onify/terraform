resource "kubernetes_stateful_set" "onify-api" {
  metadata {
    name      = "onify-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "onify-api"
      name = "onify-api"
    }
  }
  spec {
    service_name = "onify-api"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "onify-api"
        task = "onify-api"
      }
    }
    template {
      metadata {
        labels = {
          app  = "onify-api"
          task = "onify-api"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/api:${var.onify-api_version}"
          name  = "onfiy-api"
          resources {
            limits = {
              cpu    = var.onify-api_cpu_limit
              memory = var.onify-api_memory_limit
            }
            requests = {
              cpu    = var.onify-api_cpu_requests
              memory = var.onify-api_memory_requests
            }
          }
          port {
            name           = "onify-api"
            container_port = 8181
          }
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

resource "kubernetes_service" "onify-api" {
  metadata {
    name      = "onify-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    selector = {
      app  = "onify-api"
      task = "onify-api"
    }
    port {
      name     = "onify-api"
      port     = 8181
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}
