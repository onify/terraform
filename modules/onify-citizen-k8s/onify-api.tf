resource "kubernetes_config_map" "onify-api" {
  metadata {
    name      = "${local.namespace}-api"
    namespace = local.workload_namespace
  }

  data = {
    ONIFY_db_elasticsearch_host = coalesce(var.elasticsearch_address, "http://${local.namespace}-elasticsearch:9200")
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_stateful_set" "onify-api" {
  metadata {
    name      = "${local.namespace}-api"
    namespace = local.workload_namespace
    labels = {
      app  = "${local.namespace}-api"
      name = "${local.namespace}-api"
    }
  }
  spec {
    service_name = "${local.namespace}-api"
    replicas     = 1
    selector {
      match_labels = {
        app  = "${local.namespace}-api"
        task = "${local.namespace}-api"
      }
    }
    template {
      metadata {
        annotations = {
          "checksum/api-config" = sha256(jsonencode(kubernetes_config_map.onify-api.data))
        }
        labels = {
          app  = "${local.namespace}-api"
          task = "${local.namespace}-api"
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
          image             = var.onify_api_image
          image_pull_policy = "IfNotPresent"
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
          dynamic "env_from" {
            for_each = var.runtime_secrets.api[*]
            content {
              secret_ref { name = env_from.value }
            }
          }
          env_from {
            config_map_ref {
              name = "${local.namespace}-api"
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_service" "onify-api" {
  lifecycle { create_before_destroy = true }
  metadata {
    name      = "onify-citizen-api"
    namespace = local.workload_namespace
  }
  spec {
    selector = {
      app  = "${local.namespace}-api"
      task = "${local.namespace}-api"
    }
    port {
      name     = "api"
      port     = 8181
      protocol = "TCP"
    }
    type = "ClusterIP"
  }
}
