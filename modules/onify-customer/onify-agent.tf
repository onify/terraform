resource "kubernetes_stateful_set" "onify-hub-agent" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-agent"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-hub-agent"
      name = "${local.client_code}-${local.onify_instance}"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-hub-agent"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-hub-agent"
        task = "${local.client_code}-${local.onify_instance}-hub-agent"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-hub-agent"
          task = "${local.client_code}-${local.onify_instance}-hub-agent"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.onify_hub_agent_image
          name  = "onfiy-hub-agent"
          port {
            name           = "hub-agent"
            container_port = 8080
          }
          dynamic "env" {
            for_each = var.onify_agent_envs
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}

resource "kubernetes_service" "onify-hub-agent" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-agent"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-hub-agent"
      task = "${local.client_code}-${local.onify_instance}-hub-agent"
    }
    port {
      name     = "hub-agent"
      port     = 8080
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_secret.docker-onify]
}



resource "kubernetes_ingress_v1" "onify-hub-agent" {
  count                  = var.onify_hub_agent_external && var.ingress ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-agent"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}-hub-agent.${var.external_dns_domain}"]
      secret_name = var.onify_hub_agent_tls != null ? var.onify_hub_agent_tls : "tls-secret-hub-agent-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        hosts       = ["${tls.value}-api.${var.external_dns_domain}"]
        secret_name = var.onify_hub_agent_tls != null ? var.onify_hub_agent_tls : "tls-secret-hub-agent-${var.tls}-custom-${tls.value}"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-hub-agent.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-hub-agent"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname != null ? toset(var.custom_hostname) : []
      content {
        host = "${rule.value}-hub-agent.${var.external_dns_domain}"
        http {
          path {
            backend {
              service {
                name = "${local.client_code}-${local.onify_instance}-hub-agent"
                port {
                  number = 8080
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
