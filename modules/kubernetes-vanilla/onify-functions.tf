resource "kubernetes_stateful_set" "onify-functions" {
  metadata {
    name      = "onify-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "onify-functions"
      name = "onify-functions"
    }
  }
  spec {
    service_name = "onify-functions"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "onify-functions"
        task = "onify-functions"
      }
    }
    template {
      metadata {
        labels = {
          app  = "onify-functions"
          task = "onify-functions"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/functions:latest"
          name  = "onfiy-api"
          port {
            name           = "onify-functions"
            container_port = 8282
          }
          dynamic "env" {
            for_each = var.onify_default_envs
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

resource "kubernetes_service" "onify-functions" {
  metadata {
    name      = "onify-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    selector = {
      app  = "onify-functions"
      task = "onify-functions"
    }
    port {
      name     = "onify-functions"
      port     = 8282
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}
