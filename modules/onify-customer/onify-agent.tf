resource "kubernetes_secret" "docker-onify" {
  metadata {
    name      = "onify-regcred"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "eu.gcr.io": {
      "auth": "${base64encode("_json_key:${file("${var.gcr_registry_keyfile}")}")}"
    }
    "ghcr.io": {
      "auth": "${base64encode("${var.ghcr_registry_username}:${var.ghcr_registry_password}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_stateful_set" "onify-agent" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-agent"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-agent"
      name = "${local.client_code}-${local.onify_instance}"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-agent"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-agent"
        task = "${local.client_code}-${local.onify_instance}-agent"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-agent"
          task = "${local.client_code}-${local.onify_instance}-agent"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = "eu.gcr.io/onify-images/hub/agent-server:${var.onify-agent_version}"
          name  = "onfiy-agent"
          port {
            name           = "onify-agent"
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
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_service" "onify-agent" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-agent"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }
  spec {
    //external_traffic_policy = "Local"
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-agent"
      task = "${local.client_code}-${local.onify_instance}-agent"
    }
    port {
      name     = "onify-agent"
      port     = 8080
      protocol = "TCP"
    }
    //type = "NodePort"
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}



resource "kubernetes_ingress_v1" "onify-agent" {
  count                  = var.onify-agent_external ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-agent"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts = ["${local.client_code}-${local.onify_instance}-agent.${var.external-dns-domain}"]
      secret_name = var.onify-agent_tls != null ? var.onify-agent_tls : "tls-secret-agent-${var.tls}"
    }
    dynamic "tls" {
      for_each = var.custom_hostname!= null ? [1] : []
      content {
        hosts = ["${var.custom_hostname}-api.${var.external-dns-domain}"]
        secret_name = "tls-secret-agent-${var.tls}-custom"
      }
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-agent.${var.external-dns-domain}"
      http {
        path {
          backend {
            service {
            name = "${local.client_code}-${local.onify_instance}-agent"
            port {
              number = 8080
            }
            }
          }
          #path = "/agent"
          #path_type = "Prefix"
        }
      }
    }
    dynamic "rule" {
      for_each = var.custom_hostname!= null ? [1] : []
      content {
        host = "${var.custom_hostname}-agent.${var.external-dns-domain}"
        http {
          path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-agent"
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
  depends_on = [kubernetes_namespace.customer_namespace]
}
