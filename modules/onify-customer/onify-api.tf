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
          resources {
            limits = {
              cpu    = var.onify-api_cpu_limit
              memory = var.onify-api_memory_limit
            }
            requests = {
              cpu    = var.onify-api_cpu_requests
              memory = var.onify-api_memory_requests
            }
          }
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
      "kubernetes.io/ingress.class" = "public"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/connection-proxy-header" = "upgrade"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "555m"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "5555"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "5555"
      "nginx.ingress.kubernetes.io/configuration-snippet" = <<APA
        proxy_set_header Upgrade "websockets";
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_socket_keepalive on;
        APA
    }
  }
  spec {
    tls {
      hosts = ["api.${var.external-dns-domain}"]
      secret_name = "tls-secret-api"
    }
    ingress_class_name = "public"
    rule {
      host = "api.${var.external-dns-domain}"
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
  depends_on = [kubernetes_namespace.customer_namespace]
}
