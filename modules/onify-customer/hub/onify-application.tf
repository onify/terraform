resource "kubernetes_config_map" "onify-app-hub" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app-hub"
    namespace = "${local.client_code}-${local.onify_instance}"
  }

  data = {
    ONIFY_api_internalUrl = "http://${local.client_code}-${local.onify_instance}-api:8181/api/v2"
  }
}

resource "kubernetes_stateful_set" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-app"
      name = "${local.client_code}-${local.onify_instance}-app"
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
          name = "onify-regcred"
        }
        container {
          image = var.onify-app_image
          name  = "onfiy-api"
          port {
            name           = "onify-app"
            container_port = 3000
          }
          dynamic "env" {
            for_each = var.onify_app_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env_from {
            config_map_ref {
              name = "${local.client_code}-${local.onify_instance}-app-hub"
            }
          }

        }
      }
    }
  }
  depends_on = [kubernetes_config_map.onify-app-hub]
}

resource "kubernetes_service" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-app"
      task = "${local.client_code}-${local.onify_instance}-app"
    }
    port {
      name     = "onify-app"
      port     = 3000
      protocol = "TCP"
    }
    type = "NodePort"
  }
  depends_on = [kubernetes_stateful_set.onify-app]
}

resource "kubernetes_ingress_v1" "onify-app" {
  count                  = var.vanilla ? 0 : 1
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    annotations = {
      "cert-manager.io/cluster-issuer"                 = "letsencrypt-${var.tls}"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "100m"
    }
  }
  spec {
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}-app.${var.external-dns-domain}"]
      secret_name = var.onify-app_tls != null ? var.onify-app_tls : "tls-secret-app-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}.${var.external-dns-domain}"]
        secret_name = "tls-secret-app-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-app.${var.external-dns-domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-app"
              port {
                number = 3000
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}.${var.external-dns-domain}"
        http {
          path {
            backend {
              service {
                name = "${local.client_code}-${local.onify_instance}-app"
                port {
                  number = 3000
                }
              }
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_service.onify-app]
}
