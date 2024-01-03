resource "kubernetes_stateful_set" "onify-functions" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-functions"
      name = "${local.client_code}-${local.onify_instance}-functions"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-functions"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-functions"
        task = "${local.client_code}-${local.onify_instance}-functions"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-functions"
          task = "${local.client_code}-${local.onify_instance}-functions"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.onify-functions_image
          name  = "onfiy-api"
          port {
            name           = "onify-functions"
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

resource "kubernetes_service" "onify-functions" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-functions"
      task = "${local.client_code}-${local.onify_instance}-functions"
    }
    port {
      name     = "onify-functions"
      port     = 8282
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}
resource "kubernetes_ingress_v1" "onify-functions" {
  count                  = var.onify-functions_external && !var.vanilla ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}-functions.${var.external-dns-domain}"]
      secret_name = "tls-secret-functions-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts = ["${tls.value}-functions.${var.external-dns-domain}"]
        secret_name = "tls-secret-functions-${var.tls}-custom"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-functions.${var.external-dns-domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-functions"
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
        host = "${rule.value}-functions.${var.external-dns-domain}"
        http {
          path {
            backend {
              service {
                name = "${local.client_code}-${local.onify_instance}-functions"
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
