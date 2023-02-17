resource "kubernetes_config_map" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = "${local.client_code}-${local.onify_instance}"
  }

  data = {
    ONIFY_api_internalUrl = "http://${local.client_code}-${local.onify_instance}-api:8181/api/v2"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_stateful_set" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
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
          image = "eu.gcr.io/onify-images/hub/app:${var.onify-app_version}"
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
              name = "${local.client_code}-${local.onify_instance}-app"
            }
          }

        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_service" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
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
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_ingress_v1" "onify-app" {
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts = ["${local.client_code}-${local.onify_instance}-app.${var.external-dns-domain}"]
      secret_name = "tls-secret-app-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname!= null ? [1] : []
      content {
        hosts = ["${var.custom_hostname}.${var.external-dns-domain}"]
        secret_name = "tls-secret-app-${var.tls}-custom"
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
        }
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-app-helix"
            port {
              number = 3000
            }
            } 
          }
          path = "/app/*"
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname!= null ? [1] : []
      content {
        host = "${var.custom_hostname}.${var.external-dns-domain}"
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
  depends_on = [kubernetes_namespace.customer_namespace]
}
