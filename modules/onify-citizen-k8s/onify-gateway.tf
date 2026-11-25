locals {
  gateway_name = "${local.namespace}-gateway"
}

resource "kubernetes_deployment_v1" "onify-gateway" {
  metadata {
    name      = local.gateway_name
    namespace = local.workload_namespace
    labels = {
      app = local.gateway_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.gateway_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.gateway_name
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
          name              = "gateway"
          image             = var.onify_gateway_image
          image_pull_policy = "IfNotPresent"

          readiness_probe {
            http_get {
              path = "/health/ready"
              port = 8686
            }
            period_seconds = 5
          }
          port {
            name           = "gateway"
            container_port = 8686
            protocol       = "TCP"
          }

          dynamic "env" {
            for_each = merge(try(local.profile.gateway_envs, {}), var.onify_gateway_envs, { PORT = "8686" })
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env_from" {
            for_each = var.runtime_secrets.gateway[*]
            content {
              secret_ref { name = env_from.value }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "onify-gateway" {
  lifecycle { create_before_destroy = true }

  metadata {
    name      = "onify-citizen-gateway"
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    labels = {
      app = local.gateway_name
    }
  }

  spec {
    selector = {
      app = local.gateway_name
    }
    type = "ClusterIP"

    port {
      name        = "gateway"
      port        = 8686
      target_port = "gateway"
      protocol    = "TCP"
    }
  }
}
