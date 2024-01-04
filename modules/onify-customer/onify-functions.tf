resource "kubernetes_stateful_set" "onify-hub-functions" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-hub-functions"
      name = "${local.client_code}-${local.onify_instance}-hub-functions"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-hub-functions"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-hub-functions"
        task = "${local.client_code}-${local.onify_instance}-hub-functions"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-hub-functions"
          task = "${local.client_code}-${local.onify_instance}-hub-functions"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.onify_hub_functions_image
          name  = "onfiy-hub-functions"
          port {
            name           = "hub-functions"
            container_port = 8282
          }
          dynamic "env" {
            for_each = var.onify_functions_envs
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}

resource "kubernetes_service" "onify-hub-functions" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-hub-functions"
      task = "${local.client_code}-${local.onify_instance}-hub-functions"
    }
    port {
      name     = "hub-functions"
      port     = 8282
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}
resource "kubernetes_ingress_v1" "onify-hub-functions" {
  count                  = var.onify_hub_functions_external && var.ingress ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}-hub-functions.${var.external_dns_domain}"]
      secret_name = "tls-secret-hub-functions-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts = ["${tls.value}-hub-functions.${var.external_dns_domain}"]
        secret_name = length(regexall("custom", var.tls)) > 0 ? var.tls : "tls-secret-hub-functions-${var.tls}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-hub-functions.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-hub-functions"
              port {
                number = 8282
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}-hub-functions.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = "${local.client_code}-${local.onify_instance}-hub-functions"
                port {
                  number = 8282
                }
              }
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}
