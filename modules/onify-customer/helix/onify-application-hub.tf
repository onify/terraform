resource "kubernetes_stateful_set" "onify-hub-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    labels = {
      app  = "${local.client_code}-${local.onify_instance}-hub-app"
      name = "${local.client_code}-${local.onify_instance}-hub-app"
    }
  }
  spec {
    service_name = "${local.client_code}-${local.onify_instance}-hub-app"
    replicas     = var.deployment_replicas
    selector {
      match_labels = {
        app  = "${local.client_code}-${local.onify_instance}-hub-app"
        task = "${local.client_code}-${local.onify_instance}-hub-app"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.client_code}-${local.onify_instance}-hub-app"
          task = "${local.client_code}-${local.onify_instance}-hub-app"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.onify_hub_app_image
          name  = "onfiy-api"
          port {
            name           = "hub-app"
            container_port = 3000
          }
          dynamic "env" {
            for_each = var.onify_hub_app_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env {
            name  = "ONIFY_api_internalUrl"
            value = "http://${local.client_code}-${local.onify_instance}-hub-api:8181/api/v2"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "onify-hub-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-hub-app"
    namespace = "${local.client_code}-${local.onify_instance}"
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = jsonencode({ ingress : true })
    }
  }
  spec {
    selector = {
      app  = "${local.client_code}-${local.onify_instance}-hub-app"
      task = "${local.client_code}-${local.onify_instance}-hub-app"
    }
    port {
      name     = "hub-app"
      port     = 3000
      protocol = "TCP"
    }
    type = "NodePort"
  }
  depends_on = [kubernetes_stateful_set.onify-hub-app]
}

