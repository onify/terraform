resource "kubernetes_config_map" "onify-hub-api" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }

  data = {
    ONIFY_db_elasticsearch_host = var.elasticsearch_address != null ? var.elasticsearch_address : "http://${local.client_code}-${local.onify_instance}-elasticsearch:9200"
    ONIFY_websockets_agent_url  = "ws://${local.client_code}-${local.onify_instance}-agent:8080/hub"
  }
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}

resource "kubernetes_stateful_set" "onify-hub-api" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-hub-api"
      name = "${local.client_code}-${local.onify_instance}-hub-api"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-hub-api"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-hub-api"
        task = "${local.client_code}-${local.onify_instance}-hub-api"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-hub-api"
          task = "${local.client_code}-${local.onify_instance}-hub-api"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.onify_hub_api_image
          name  = "onfiy-hub-api"
          port {
            name           = "hub-api"
            container_port = 8181
          }
          dynamic "env" {
            for_each = var.onify_hub_api_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env_from {
            config_map_ref {
              name = "${local.client_code}-${local.onify_instance}-hub-api"
            }
          }
        }
        node_name = var.kubernetes_node_api_worker != null ? var.kubernetes_node_api_worker : null
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}

resource "kubernetes_service" "onify-hub-api" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-hub-api"
      task = "${local.client_code}-${local.onify_instance}-hub-api"
    }
    port {
      name     = "hub-api"
      port     = 8181
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}


resource "kubernetes_ingress_v1" "onify-hub-api" {
  count                  = var.onify_hub_api_external && var.ingress ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer"                 = "letsencrypt-${var.tls}"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
    }
  }
  spec {
    tls {
      hosts = ["${local.client_code}-${local.onify_instance}-hub-api.${var.external_dns_domain}"]
      secret_name = var.onify_hub_api_tls != null ? var.onify_hub_api_tls : "tls-secret-hub-api-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname!= null ? toset(var.custom_hostname) : []
      content {
        hosts = ["${tls.value}-hub-api.${var.external_dns_domain}"]
        secret_name = "tls-secret-hub-api-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-hub-api.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-hub-api"
              port {
                number = 8181
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}-hub-api.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = "${local.client_code}-${local.onify_instance}-hub-api"
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
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]
}
