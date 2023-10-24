resource "kubernetes_config_map" "onify-api" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }

  data = {
    ONIFY_db_elasticsearch_host = var.elasticsearch_address != null ? var.elasticsearch_address : "http://${local.client_code}-${local.onify_instance}-elasticsearch:9200"
    ONIFY_websockets_agent_url  = "ws://${local.client_code}-${local.onify_instance}-agent:8080/hub"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_stateful_set" "onify-api" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-api"
      name = "${local.client_code}-${local.onify_instance}-api"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-api"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-api"
        task = "${local.client_code}-${local.onify_instance}-api"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-api"
          task = "${local.client_code}-${local.onify_instance}-api"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/api:${var.onify-api_version}"
          name  = "onfiy-api"
          port {
            name           = "onify-api"
            container_port = 8181
          }
           dynamic "env" {
            for_each = var.onify_api_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env_from {
            config_map_ref {
              name = "${local.client_code}-${local.onify_instance}-api"
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_service" "onify-api" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-api"
      task = "${local.client_code}-${local.onify_instance}-api"
    }
    port {
      name     = "onify-api"
      port     = 8181
      protocol = "TCP"
    }
    //type = "NodePort"
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}


resource "kubernetes_ingress_v1" "onify-api" {
  count                  = var.onify-api_external ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
    }
  }
  spec {
    tls {
      hosts = ["${local.client_code}-${local.onify_instance}-api.${var.external-dns-domain}"]
      secret_name = "tls-secret-api-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname!= null ? toset(var.custom_hostname) : []
      content {
        hosts = ["${tls.value}-api.${var.external-dns-domain}"]
        secret_name = "tls-secret-api-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-api.${var.external-dns-domain}" 
      http {
        path {
          backend {
            service {
            name = "${local.client_code}-${local.onify_instance}-api"
            port {
              number = 8181
            }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname!= null ? [1] : []
      content {
        host = "${rule.value}-api.${var.external-dns-domain}"
        http {
          path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-api"
            port {
              number = 8181
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
