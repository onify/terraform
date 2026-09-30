locals {
  hub_gateway_name = "${local.client_code}-${local.onify_instance}-hub-gateway"
}

resource "kubernetes_stateful_set" "onify-hub-gateway" {
  count = var.onify_hub_gateway_image != null ? 1 : 0

  metadata {
    name      = local.hub_gateway_name
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    labels = {
      app  = local.hub_gateway_name
      name = local.hub_gateway_name
    }
  }

  spec {
    service_name = local.hub_gateway_name
    replicas     = var.deployment_replicas

    selector {
      match_labels = {
        app  = local.hub_gateway_name
        task = local.hub_gateway_name
      }
    }

    template {
      metadata {
        labels = {
          app  = local.hub_gateway_name
          task = local.hub_gateway_name
        }
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

          dynamic "resources" {
            for_each = var.onify_hub_gateway_memory_limit != null || var.onify_hub_gateway_cpu_limit != null || var.onify_hub_gateway_memory_requests != null || var.onify_hub_gateway_cpu_requests != null ? [1] : []
            content {
              limits = var.onify_hub_gateway_memory_limit != null || var.onify_hub_gateway_cpu_limit != null ? {
                memory = var.onify_hub_gateway_memory_limit
                cpu    = var.onify_hub_gateway_cpu_limit
              } : {}
              requests = var.onify_hub_gateway_memory_requests != null || var.onify_hub_gateway_cpu_requests != null ? {
                memory = var.onify_hub_gateway_memory_requests
                cpu    = var.onify_hub_gateway_cpu_requests
              } : {}
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}

resource "kubernetes_service_v1" "onify-hub-gateway" {
  count = var.onify_hub_gateway_image != null ? 1 : 0

  metadata {
    name      = local.hub_gateway_name
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    labels    = { app = local.hub_gateway_name }
    annotations = {
      "cloud.google.com/neg" = jsonencode({ ingress : true })
    }
  }

  spec {
    selector = {
      app  = local.hub_gateway_name
      task = local.hub_gateway_name
    }
    type = "ClusterIP"

    port {
      name        = "hub-gateway"
      port        = 8686
      target_port = "hub-gateway"
      protocol    = "TCP"
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}

resource "kubernetes_service_v1" "onify-hub-gateway-alias" {
  count = var.onify_hub_gateway_image != null ? 1 : 0

  metadata {
    name      = "hub-gateway"
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    annotations = {
      "cloud.google.com/neg" = jsonencode({ ingress : true })
    }
  }

  spec {
    selector = kubernetes_service_v1.onify-hub-gateway[0].spec[0].selector
    type     = "ClusterIP"

    port {
      name        = "hub-gateway"
      port        = 8686
      target_port = "hub-gateway"
      protocol    = "TCP"
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}

resource "kubernetes_ingress_v1" "onify-hub-gateway" {
  count                  = var.onify_hub_gateway_image != null && var.onify_hub_gateway_external && var.ingress ? 1 : 0
  wait_for_load_balancer = false

  metadata {
    name      = local.hub_gateway_name
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }

  spec {
    tls {
      hosts       = ["${local.hub_gateway_name}.${var.external_dns_domain}"]
      secret_name = var.onify_hub_gateway_tls != null ? var.onify_hub_gateway_tls : "tls-secret-hub-gateway-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}-hub-gateway.${var.external_dns_domain}"]
        secret_name = var.onify_hub_gateway_tls != null ? var.onify_hub_gateway_tls : "tls-secret-hub-gateway-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.hub_gateway_name}.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = kubernetes_service_v1.onify-hub-gateway[0].metadata[0].name
              port {
                number = 8686
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}-hub-gateway.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = kubernetes_service_v1.onify-hub-gateway[0].metadata[0].name
                port {
                  number = 8686
                }
              }
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}
