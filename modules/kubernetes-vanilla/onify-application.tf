resource "kubernetes_stateful_set" "onify-app" {
  metadata {
    name      = "onify-app"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "onify-app"
      name = "onify-app"
    }
  }
  spec {
    service_name = "onify-app"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "onify-app"
        task = "onify-app"
      }
    }
    template {
      metadata {
        labels = {
          app  = "onify-app"
          task = "onify-app"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/app:${var.onify-app_version}"
          name  = "onfiy-app"
          resources {
            limits = {
              cpu    = var.onify-app_cpu_limit
              memory = var.onify-app_memory_limit
            }
            requests = {
              cpu    = var.onify-app_cpu_requests
              memory = var.onify-app_memory_requests
            }
          }
          port {
            name           = "onify-app"
            container_port = 3000
          }
          dynamic "env" {
            for_each = var.onify_default_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env" {
            for_each = var.onify_app_envs
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

resource "kubernetes_service" "onify-app" {
  metadata {
    name      = "onify-app"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    selector = {
      app  = "onify-app"
      task = "onify-app"
    }
    port {
      name     = "onify-app"
      port     = 3000
      protocol = "TCP"
    }
    type = "NodePort"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}
