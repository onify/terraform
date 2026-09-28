resource "kubernetes_stateful_set" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    labels = {
      app = "${local.client_code}-${local.onify_instance}-app"
    }
  }

  spec {
    service_name = "${local.client_code}-${local.onify_instance}-app"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-app"
        task = "${local.client_code}-${local.onify_instance}-app"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-app"
          task = "${local.client_code}-${local.onify_instance}-app"
        }
      }
      spec {
        image_pull_secrets {
          name = kubernetes_secret.docker-onify.metadata[0].name
        }
        container {
          name              = "onify-app"
          image             = var.onify_app_image
          image_pull_policy = "Always"
          port {
            name           = "app"
            container_port = 4000
          }
          dynamic "env" {
            for_each = var.onify_app_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "resources" {
            for_each = var.onify_app_memory_limit != null || var.onify_app_cpu_limit != null || var.onify_app_memory_requests != null || var.onify_app_cpu_requests != null ? [1] : []
            content {
              limits = var.onify_app_memory_limit != null || var.onify_app_cpu_limit != null ? {
                memory = var.onify_app_memory_limit
                cpu    = var.onify_app_cpu_limit
              } : {}
              requests = var.onify_app_memory_requests != null || var.onify_app_cpu_requests != null ? {
                memory = var.onify_app_memory_requests
                cpu    = var.onify_app_cpu_requests
              } : {}
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = jsonencode({ ingress : true })
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-app"
      task = "${local.client_code}-${local.onify_instance}-app"
    }
    port {
      name     = "app"
      port     = 4000
      protocol = "TCP"
    }
  }
  depends_on = [kubernetes_stateful_set.onify-app]
}

resource "kubernetes_ingress_v1" "onify-app" {
  count                  = var.ingress ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = kubernetes_namespace.customer_namespace.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                 = "letsencrypt-${var.tls}"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}.${var.external_dns_domain}"]
      secret_name = var.onify_app_tls != null ? var.onify_app_tls : "tls-secret-app-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}.${var.external_dns_domain}"]
        secret_name = var.onify_app_tls != null ? var.onify_app_tls : "tls-secret-app-${var.tls}-custom-${tls.value}"
      }
    }
    rule {
      host = "${local.client_code}-${local.onify_instance}.${var.external_dns_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.onify-app.metadata[0].name
              port {
                number = 4000
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}.${var.external_dns_domain}"
        http {
          path {
            path      = "/"
            path_type = "Prefix"
            backend {
              service {
                name = kubernetes_service.onify-app.metadata[0].name
                port {
                  number = 4000
                }
              }
            }
          }
        }
      }
    }
  }
}
