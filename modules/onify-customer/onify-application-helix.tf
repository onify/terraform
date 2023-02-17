resource "kubernetes_config_map" "onify-app-helix" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app-helix"
    namespace = "${local.client_code}-${local.onify_instance}"
  }

  data = {
    ONIFY_api_internalUrl = "http://${local.client_code}-${local.onify_instance}-api:8181/api/v2"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_stateful_set" "onify-app-helix" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app-helix"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-app-helix"
      name = "${local.client_code}-${local.onify_instance}-app-helix"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-app-helix"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-app-helix"
        task = "${local.client_code}-${local.onify_instance}-app-helix"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-app-helix"
          task = "${local.client_code}-${local.onify_instance}-app-helix"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/app:${var.onify-app_version}"
          name  = "onfiy-app"
          port {
            name           = "onify-app-helix"
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
              name = "${local.client_code}-${local.onify_instance}-app-helix"
            }
          }

        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_service" "onify-app-helix" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app-helix"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-app-helix"
      task = "${local.client_code}-${local.onify_instance}-app-helix"
    }
    port {
      name     = "onify-app-helix"
      port     = 3000
      protocol = "TCP"
    }
    type = "NodePort"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_ingress_v1" "onify-app-helix" {
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app-helix"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts = ["${local.client_code}-${local.onify_instance}-app-helix.${var.external-dns-domain}"]
      secret_name = "tls-secret-app-helix-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname!= null ? [1] : []
      content {
        hosts = ["${var.custom_hostname}.${var.external-dns-domain}"]
        secret_name = "tls-secret-app-helix-${var.tls}-custom"
      }
    }
    ingress_class_name = "nginx"
    rule {
    host = "${local.client_code}-${local.onify_instance}-app-helix.${var.external-dns-domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-app-helix"
            port {
              number = 3000
            }
            } 
          }
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
              name = "${local.client_code}-${local.onify_instance}-app-helix"
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
