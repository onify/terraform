# ### EXAMPLE SSD STORAGE CLASS
# resource "kubernetes_storage_class" "ssd" {
#   count = var.elasticsearch_address != null ? 0 : 1
#   metadata {
#     name = "ssd"
#   }
#   storage_provisioner = "kubernetes.io/gce-pd"
#   parameters = {
#     type = "pd-ssd"
#   }
#   mount_options = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
# }

resource "kubernetes_persistent_volume" "local" {
  count = var.elasticsearch_address != null ? 0 : 1
  metadata {
    name = "${local.client_code}-${local.onify_instance}-data"
  }
  spec {
    storage_class_name = "local"
    capacity = {
      storage = var.elasticsearch_disksize
    }
    persistent_volume_reclaim_policy = "Retain" // performs a basic scrub (rm -rf /thevolume/*) on the volume and makes it available again for a new claim"
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
     host_path {
        path = "/usr/share/elasticsearch/data"
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_service" "elasticsearch" {
  count = var.elasticsearch_address != null ? 0 : 1
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-elasticsearch"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    labels = {
      app = "${local.client_code}-${local.onify_instance}"
    }
  }
  spec {
    selector = {
      app = "${local.client_code}-${local.onify_instance}-elasticsearch"
    }
    port {
      name     = "client"
      port     = 9200
      protocol = "TCP"
    }
    port {
      name     = "nodes"
      port     = 9300
      protocol = "TCP"
    }
    type = "NodePort"
    //type = "LoadBalancer"
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}


resource "kubernetes_stateful_set" "elasticsearch" {
  count = var.elasticsearch_address != null ? 0 : 1
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-elasticsearch"
    namespace = "${local.client_code}-${local.onify_instance}"
    labels = {
      app = "${local.client_code}-${local.onify_instance}-elasticsearch"
    }
  }
  spec {
    pod_management_policy  = "Parallel"
    replicas               = 1
    revision_history_limit = 5
    selector {
      match_labels = {
        app = "${local.client_code}-${local.onify_instance}-elasticsearch"
      }
    }
    service_name = "${local.client_code}-${local.onify_instance}-elasticsearch"
    template {
      metadata {
        labels = {
          app = "${local.client_code}-${local.onify_instance}-elasticsearch"
        }
      }
      spec {
        security_context {
          fs_group        = 2000
          run_as_user     = 1000
          run_as_non_root = true
        }
        container {
          name  = "${local.client_code}-${local.onify_instance}-elasticsearch"
          image = "docker.elastic.co/elasticsearch/elasticsearch:${var.elasticsearch_version}"

          port {
            name           = "nodes"
            container_port = 9300
          }
          port {
            name           = "client"
            container_port = 9200
          }
          env {
            name  = "discovery.type"
            value = "single-node"
          }
          env {
            name  = "cluster.name"
            value = "${local.client_code}-${local.onify_instance}-onify-elasticsearch"
          }
          dynamic "env" {
            for_each = var.elasticsearch_heapsize != null ? [1] : []
            content {
              name  = "ES_JAVA_OPTS"
              value = "-Xms${var.elasticsearch_heapsize} -Xmx${var.elasticsearch_heapsize}"
            }
          }
          volume_mount {
            name       = "${local.client_code}-${local.onify_instance}-data"
            mount_path = "/usr/share/elasticsearch/data"
          }
          
          resources {
            limits = {
              memory = var.elasticsearch_memory_limit
            }
            # requests = {
            #   memory = var.elasticsearch_memory_requests
            # }
          }
          # liveness_probe {
          #   http_get {
          #     path   = "/_cluster/health"
          #     port   = 9200
          #     scheme = "HTTP"
          #   }
          #   initial_delay_seconds = 30
          #   timeout_seconds       = 30
          # }
        }
        termination_grace_period_seconds = 300
      }
    }
    update_strategy {
      type = "RollingUpdate"

      rolling_update {
        partition = 1
      }
    }
    volume_claim_template {
      metadata {
        name      = "${local.client_code}-${local.onify_instance}-data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        storage_class_name = var.gke ? "" : "local" #use ssd for faster disks
        resources {
          requests = {
            storage = var.elasticsearch_disksize
          }
        }
      }
    }
  }
  # provisioner "local-exec" {
  #       when = destroy    
  #       command = "kubectl delete pvc ${local.client_code}-${local.onify_instance}-data -n ${kubernetes_namespace.customer_namespace.metadata.0.name}"
  # }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_persistent_volume.local]
}
