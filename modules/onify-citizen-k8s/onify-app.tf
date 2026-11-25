resource "kubernetes_stateful_set" "onify-app" {
  metadata {
    name      = "${local.namespace}-app"
    namespace = local.workload_namespace
    labels = {
      app = "${local.namespace}-app"
    }
  }

  spec {
    service_name = "${local.namespace}-app"
    replicas     = 1
    selector {
      match_labels = {
        app  = "${local.namespace}-app"
        task = "${local.namespace}-app"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${local.namespace}-app"
          task = "${local.namespace}-app"
        }
      }
      spec {
        dynamic "image_pull_secrets" {
          for_each = kubernetes_secret.registry
          content {
            name = image_pull_secrets.value.metadata[0].name
          }
        }

        container {
          name              = "onify-app"
          image             = var.onify_app_image
          image_pull_policy = "IfNotPresent"
          port {
            name           = "app"
            container_port = 4000
          }
          dynamic "env" {
            for_each = var.onify_app_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env_from" {
            for_each = var.runtime_secrets.app[*]
            content {
              secret_ref { name = env_from.value }
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_service.onify-api]
}

resource "kubernetes_service" "onify-app" {
  lifecycle { create_before_destroy = true }
  metadata {
    name      = "onify-citizen-app"
    namespace = local.workload_namespace
  }
  spec {
    selector = {
      app  = "${local.namespace}-app"
      task = "${local.namespace}-app"
    }
    port {
      name     = "app"
      port     = 4000
      protocol = "TCP"
    }
  }
}
