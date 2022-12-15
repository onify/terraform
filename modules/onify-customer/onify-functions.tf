resource "kubernetes_stateful_set" "onify-functions" {
  metadata {
    name      = "onify-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "onify-functions"
      name = "onify-functions"
    }
  }
  spec {
    service_name = "onify-functions"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "onify-functions"
        task = "onify-functions"
      }
    }
    template {
      metadata {
        labels = {
          app  = "onify-functions"
          task = "onify-functions"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/functions:latest"
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
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_service" "onify-functions" {
  metadata {
    name      = "onify-functions"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    selector = {
      app  = "onify-functions"
      task = "onify-functions"
    }
    port {
      name     = "onify-functions"
      port     = 8282
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}
resource "kubernetes_ingress_v1" "onify-functions" {
  count                  = var.onify-functions_external ? 1 : 0
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
      hosts = ["${local.client_code}-${local.onify_instance}-functions.${var.external-dns-domain}"]
      secret_name = "tls-secret-api"
    }
    ingress_class_name = "public"
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
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}
