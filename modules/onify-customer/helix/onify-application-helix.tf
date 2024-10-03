resource "kubernetes_config_map" "onify-helix-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-helix-app"
    namespace = "${local.client_code}-${local.onify_instance}"
  }

  data = {
    ONIFY_api_internalUrl = "http://${local.client_code}-${local.onify_instance}-api:8181/api/v2"
  }
}

resource "kubernetes_stateful_set" "onify-helix-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-helix-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-helix-app"
      name = "${local.client_code}-${local.onify_instance}-helix-app"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-helix-app"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-helix-app"
        task = "${local.client_code}-${local.onify_instance}-helix-app"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-helix-app"
          task = "${local.client_code}-${local.onify_instance}-helix-app"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.onify_helix_image
          name  = "onfiy-helix-app"
          port {
            name           = "helix-app"
            container_port = 4000
          }
          dynamic "env" {
            for_each = var.onify_app_helix_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env {
            name  = "ONIFY_api_internalUrl"
            value = "http://${local.client_code}-${local.onify_instance}-hub-api:8181/api/v2"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "onify-helix-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-helix-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = jsonencode({ ingress : true })
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-helix-app"
      task = "${local.client_code}-${local.onify_instance}-helix-app"
    }
    port {
      name     = "helix-app"
      port     = 4000
      protocol = "TCP"
    }
  }
  depends_on = [kubernetes_stateful_set.onify-helix-app]
}

resource "kubernetes_ingress_v1" "onify-helix-app" {
  count                  = var.ingress ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-helix-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    annotations = {
      "cert-manager.io/cluster-issuer"                 = "letsencrypt-${var.tls}"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"

    }
  }
  spec {
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}.${var.external_dns_domain}"]
      secret_name = var.onify_hub_app_tls != null ? var.onify_hub_app_tls : "tls-secret-app-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}.${var.external_dns_domain}"]
        secret_name = var.onify_hub_app_tls != null ? var.onify_hub_app_tls : "tls-secret-app-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-hub-app"
              port {
                number = 3000
              }
            }
          }
          path      = var.hub_app_path
          path_type = "Prefix"
        }
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-helix-app"
              port {
                number = 4000
              }
            }
          }
          path      = var.helix_path
          path_type = "Prefix"
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = "${local.client_code}-${local.onify_instance}-hub-app"
                port {
                  number = 3000
                }
              }
            }
            path      = var.hub_app_path
            path_type = "Prefix"
          }
          path {
            backend {
              service {
                name = "${local.client_code}-${local.onify_instance}-helix-app"
                port {
                  number = 4000
                }
              }
            }
            path      = var.helix_path
            path_type = "Prefix"
          }
        }
      }
    }
  }
  depends_on = [kubernetes_service.onify-helix-app]
}

