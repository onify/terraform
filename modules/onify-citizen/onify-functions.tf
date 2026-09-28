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
          image             = var.onify_functions_image
          image_pull_policy = "Always"
          name              = "onify-functions"
          port {
            name           = "functions"
            container_port = 8282
          }
          dynamic "env" {
            for_each = var.onify_functions_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "resources" {
            for_each = var.onify_functions_memory_limit != null || var.onify_functions_cpu_limit != null || var.onify_functions_memory_requests != null || var.onify_functions_cpu_requests != null ? [1] : []
            content {
              limits = var.onify_functions_memory_limit != null || var.onify_functions_cpu_limit != null ? {
                memory = var.onify_functions_memory_limit
                cpu    = var.onify_functions_cpu_limit
              } : {}
              requests = var.onify_functions_memory_requests != null || var.onify_functions_cpu_requests != null ? {
                memory = var.onify_functions_memory_requests
                cpu    = var.onify_functions_cpu_requests
              } : {}
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}

resource "kubernetes_service" "onify-functions" {
  lifecycle { create_before_destroy = true }
  metadata {
    name      = "functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cloud.google.com/neg" = jsonencode({ ingress : true })
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-functions"
      task = "${local.client_code}-${local.onify_instance}-functions"
    }
    port {
      name     = "functions"
      port     = 8282
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "onify-functions" {
  count                  = var.onify_functions_external && var.ingress ? 1 : 0
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
      hosts       = ["${local.client_code}-${local.onify_instance}-functions.${var.external_dns_domain}"]
      secret_name = var.onify_functions_tls != null ? var.onify_functions_tls : "tls-secret-functions-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}-functions.${var.external_dns_domain}"]
        secret_name = var.onify_functions_tls != null ? var.onify_functions_tls : "tls-secret-functions-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-functions.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = kubernetes_service.onify-functions.metadata[0].name
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
        host = "${rule.value}-functions.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = kubernetes_service.onify-functions.metadata[0].name
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
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}
