locals {
  database = "${var.namespace}-elasticsearch"
}

resource "kubernetes_service_v1" "database" {
  metadata {
    name      = local.database
    namespace = var.namespace
  }
  spec {
    cluster_ip = "None"
    selector   = { app = local.database }
    port {
      name = "http"
      port = 9200
    }
  }
}

resource "kubernetes_stateful_set_v1" "database" {
  metadata {
    name      = local.database
    namespace = var.namespace
  }
  spec {
    replicas     = 1
    service_name = kubernetes_service_v1.database.metadata[0].name
    selector { match_labels = { app = local.database } }
    volume_claim_template {
      metadata { name = "data" }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.profile.storage_class
        resources { requests = { storage = "10Gi" } }
      }
    }
    template {
      metadata { labels = { app = local.database } }
      spec {
        automount_service_account_token = false
        security_context { fs_group = 1000 }
        container {
          name  = "elasticsearch"
          image = var.profile.elasticsearch_image
          env {
            name  = "discovery.type"
            value = "single-node"
          }
          env {
            name  = "ES_JAVA_OPTS"
            value = "-Xms1024m -Xmx1024m"
          }
          env {
            name  = "ingest.geoip.downloader.enabled"
            value = "false"
          }
          resources {
            requests = { memory = "2Gi" }
            limits   = { memory = "2Gi" }
          }
          volume_mount {
            name       = "data"
            mount_path = "/usr/share/elasticsearch/data"
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 9200
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_network_policy.internal]
}
