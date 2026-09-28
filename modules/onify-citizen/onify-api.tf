resource "kubernetes_config_map" "onify-api" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }

  data = {
    ONIFY_db_elasticsearch_host = var.elasticsearch_address != null ? var.elasticsearch_address : "http://elasticsearch:9200"
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify, kubernetes_service.elasticsearch]
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
        annotations = {
          "checksum/api-config" = sha256(jsonencode(kubernetes_config_map.onify-api.data))
        }
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
          image             = var.onify_api_image
          image_pull_policy = "Always"
          name              = "onify-api"
          port {
            name           = "api"
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
          dynamic "resources" {
            for_each = var.onify_api_memory_limit != null || var.onify_api_cpu_limit != null || var.onify_api_memory_requests != null || var.onify_api_cpu_requests != null ? [1] : []
            content {
              limits = var.onify_api_memory_limit != null || var.onify_api_cpu_limit != null ? {
                memory = var.onify_api_memory_limit
                cpu    = var.onify_api_cpu_limit
              } : {}
              requests = var.onify_api_memory_requests != null || var.onify_api_cpu_requests != null ? {
                memory = var.onify_api_memory_requests
                cpu    = var.onify_api_cpu_requests
              } : {}
            }
          }
        }
        node_name = var.kubernetes_node_api_worker != null ? var.kubernetes_node_api_worker : null
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}

resource "kubernetes_service" "onify-api" {
  lifecycle { create_before_destroy = true }
  metadata {
    name      = "api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = jsonencode({ ingress : true })
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-api"
      task = "${local.client_code}-${local.onify_instance}-api"
    }
    port {
      name     = "api"
      port     = 8181
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
}


resource "kubernetes_ingress_v1" "onify-api" {
  count                  = var.onify_api_external && var.ingress ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-api"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer"                 = "letsencrypt-${var.tls}"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
    }
  }
  spec {
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}-api.${var.external_dns_domain}"]
      secret_name = var.onify_api_tls != null ? var.onify_api_tls : "tls-secret-api-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}-api.${var.external_dns_domain}"]
        secret_name = var.onify_api_tls != null ? var.onify_api_tls : "tls-secret-api-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-api.${var.external_dns_domain}"

      http {
        path {
          backend {
            service {
              name = kubernetes_service.onify-api.metadata[0].name
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
        host = "${rule.value}-api.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = kubernetes_service.onify-api.metadata[0].name
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
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}
