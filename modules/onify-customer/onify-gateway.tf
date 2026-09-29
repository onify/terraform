locals {
  hub_gateway_name = "${local.client_code}-${local.onify_instance}-hub-gateway"
}

resource "kubernetes_deployment_v1" "onify-hub-gateway" {
  count = var.onify_hub_gateway_image != null ? 1 : 0

  metadata {
    name      = local.hub_gateway_name
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    labels    = { app = local.hub_gateway_name }
  }

  spec {
    replicas = var.deployment_replicas

    selector {
      match_labels = { app = local.hub_gateway_name }
    }

    template {
      metadata {
        labels = { app = local.hub_gateway_name }
      }

      spec {
        image_pull_secrets {
          name = kubernetes_secret.docker-onify.metadata[0].name
        }

        container {
          name              = "hub-gateway"
          image             = var.onify_hub_gateway_image
          image_pull_policy = "Always"

          port {
            name           = "hub-gateway"
            container_port = 8686
            protocol       = "TCP"
          }

          dynamic "env" {
            for_each = merge(var.onify_hub_gateway_envs, { PORT = "8686" })
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "onify-hub-gateway" {
  count = var.onify_hub_gateway_image != null ? 1 : 0

  metadata {
    name      = local.hub_gateway_name
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    labels    = { app = local.hub_gateway_name }
  }

  spec {
    selector = { app = local.hub_gateway_name }
    type     = "ClusterIP"

    port {
      name        = "hub-gateway"
      port        = 8686
      target_port = "hub-gateway"
      protocol    = "TCP"
    }
  }
}
