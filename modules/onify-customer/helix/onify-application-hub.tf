resource "kubernetes_config_map" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = "${local.client_code}-${local.onify_instance}"
  }

  data = {
    ONIFY_api_internalUrl = "http://${local.client_code}-${local.onify_instance}-api:8181/api/v2"
  }
}

resource "kubernetes_stateful_set" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = "${local.client_code}-${local.onify_instance}"
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
          image = var.onify-app_image
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
  depends_on = [kubernetes_config_map.onify-app]
}

resource "kubernetes_service" "onify-app" {
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-app"
    namespace = "${local.client_code}-${local.onify_instance}"
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
  depends_on = [kubernetes_stateful_set.onify-app]
}

