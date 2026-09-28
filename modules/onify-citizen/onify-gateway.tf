locals {
  gateway_name = "${local.client_code}-${local.onify_instance}-gateway"
}

resource "kubernetes_deployment_v1" "onify-gateway" {
  count = var.onify_gateway_image != null ? 1 : 0

  metadata {
    name      = local.gateway_name
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    labels = {
      app = local.gateway_name
    }
  }

  spec {
    replicas = var.deployment_replicas

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
        image_pull_secrets {
          name = kubernetes_secret.docker-onify.metadata[0].name
        }

        container {
          name              = "gateway"
          image             = var.onify_gateway_image
          image_pull_policy = "Always"

          port {
            name           = "gateway"
            container_port = 8686
            protocol       = "TCP"
          }

          dynamic "env" {
            for_each = merge(var.onify_gateway_envs, { PORT = "8686" })
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

resource "kubernetes_service_v1" "onify-gateway" {
  count = var.onify_gateway_image != null ? 1 : 0
  lifecycle { create_before_destroy = true }

  metadata {
    name      = "${var.service_name_prefix}gateway"
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
