
resource "kubernetes_stateful_set" "onify-custom-image" {
  metadata {
    name      = "${var.client_code}-${var.client_instance}-${var.name}"
    namespace = "${var.client_code}-${var.client_instance}"
    labels = {
      app  = "${var.client_code}-${var.client_instance}-${var.name}"
      name = "${var.client_code}-${var.client_instance}-${var.name}"
    }
  }
  spec {
    service_name = "${var.client_code}-${var.client_instance}-${var.name}"
    replicas     = var.pod_count
    selector {
      match_labels = {
        app  = "${var.client_code}-${var.client_instance}-${var.name}"
        task = "${var.client_code}-${var.client_instance}-${var.name}"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${var.client_code}-${var.client_instance}-${var.name}"
          task = "${var.client_code}-${var.client_instance}-${var.name}"
        }
      }
      spec {
        image_pull_secrets {
          name = "${var.client_code}-${var.client_instance}-regcred"
        }
        container {
          image = var.image
          name  = "${var.client_code}-${var.client_instance}-image"
          port {
            name           = var.name
            container_port = var.port
          }
          dynamic "env" {
            for_each = var.envs
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_secret.onify-custom-image]
}


resource "kubernetes_service" "onify-custom-image" {
  metadata {
    name      = "${var.client_code}-${var.client_instance}-${var.name}"
    namespace = "${var.client_code}-${var.client_instance}"
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = jsonencode({ ingress : true })
    }
  }
  spec {
    selector = {
      app  = "${var.client_code}-${var.client_instance}-${var.name}"
      task = "${var.client_code}-${var.client_instance}-${var.name}"
    }
    port {
      name     = "${var.client_code}-${var.client_instance}-port"
      port     = var.port
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_stateful_set.onify-custom-image]
}

resource "kubernetes_ingress_v1" "onify-name" {
  wait_for_load_balancer = false
  metadata {
    name      = "${var.client_code}-${var.client_instance}-${var.name}"
    namespace = "${var.client_code}-${var.client_instance}"
    annotations = {
      "cert-manager.io/cluster-issuer"                 = "letsencrypt-${var.tls}"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
    }
  }
  spec {
    tls {
      hosts       = ["${var.client_code}-${var.client_instance}-${var.name}.${var.external_dns_domain}"]
      secret_name = var.onify_custom_image_tls != null ? var.onify_custom_image_tls : "tls-secret-${var.name}-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}-${var.name}.${var.external_dns_domain}"]
        secret_name = var.onify_custom_image_tls != null ? var.onify_custom_image_tls : "tls-secret-${var.name}-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${var.client_code}-${var.client_instance}-${var.name}.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = "${var.client_code}-${var.client_instance}-${var.name}"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}-${var.name}.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = "${var.client_code}-${var.client_instance}-${var.name}"
                port {
                  number = 80
                }
              }
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_service.onify-custom-image]
}
