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
    persistent_volume_reclaim_policy = "Retain"
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/usr/share/elasticsearch/data"
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_persistent_volume" "elasticsearch_backup" {
  count = var.elasticsearch_backup_enabled ? 1 : 0
  metadata {
    name = "${local.client_code}-${local.onify_instance}-backup"
  }
  spec {
    storage_class_name = "local"
    capacity = {
      storage = var.elasticsearch_disksize
    }
    persistent_volume_reclaim_policy = "Retain"
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/usr/share/elasticsearch/backup"
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
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = jsonencode({ ingress : true })
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
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "kubernetes_persistent_volume_claim" "elasticsearch_data" {
  count = var.elasticsearch_address != null ? 0 : 1
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-data-${local.client_code}-${local.onify_instance}-elasticsearch-0"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.gke ? "" : "local" #use ssd for faster disks
    resources {
      requests = {
        storage = var.elasticsearch_disksize
      }
    }
    volume_name = kubernetes_persistent_volume.local[0].metadata[0].name
  }
  depends_on = [
    kubernetes_namespace.customer_namespace,
    kubernetes_persistent_volume.local
  ]
}

resource "kubernetes_persistent_volume_claim" "elasticsearch_backup" {
  count = var.elasticsearch_backup_enabled ? 1 : 0
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-backup-${local.client_code}-${local.onify_instance}-elasticsearch-0"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.gke ? "" : "local" #use ssd for faster disks
    resources {
      requests = {
        storage = var.elasticsearch_disksize
      }
    }
    volume_name = kubernetes_persistent_volume.elasticsearch_backup[0].metadata[0].name
  }
  depends_on = [
    kubernetes_namespace.customer_namespace,
    kubernetes_persistent_volume.elasticsearch_backup
  ]
}

resource "kubernetes_stateful_set" "elasticsearch" {
  count = var.elasticsearch_address != null ? 0 : 1
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-elasticsearch"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
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
          dynamic "env" {
            for_each = var.elasticsearch_backup_enabled ? [1] : []
            content {
              name  = "path.repo"
              value = "/usr/share/elasticsearch/backup"
            }
          }
          volume_mount {
            name       = "${local.client_code}-${local.onify_instance}-data"
            mount_path = "/usr/share/elasticsearch/data"
          }
          dynamic "volume_mount" {
            for_each = var.elasticsearch_backup_enabled ? [1] : []
            content {
              name       = "${local.client_code}-${local.onify_instance}-backup"
              mount_path = "/usr/share/elasticsearch/backup"
            }
          }
        }
        termination_grace_period_seconds = 300

        volume {
          name = "${local.client_code}-${local.onify_instance}-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.elasticsearch_data[0].metadata[0].name
          }
        }

        dynamic "volume" {
          for_each = var.elasticsearch_backup_enabled ? [1] : []
          content {
            name = "${local.client_code}-${local.onify_instance}-backup"
            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim.elasticsearch_backup[0].metadata[0].name
            }
          }
        }
      }
    }
    update_strategy {
      type = "RollingUpdate"

      rolling_update {
        partition = 1
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace, kubernetes_persistent_volume.local]
}

resource "kubernetes_ingress_v1" "onify-elasticsearch" {
  count                  = var.elasticsearch_external ? 1 : 0
  wait_for_load_balancer = false
  metadata {
    name      = "${local.client_code}-${local.onify_instance}-elasticsearch"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts       = ["${local.client_code}-${local.onify_instance}-elasticsearch.${var.external_dns_domain}"]
      secret_name = "tls-secret-elasticsearch-${var.tls}"
    }
    ingress_class_name = "nginx"
    rule {
      host = "${local.client_code}-${local.onify_instance}-elasticsearch.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = "${local.client_code}-${local.onify_instance}-elasticsearch"
              port {
                number = 9200
              }
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.customer_namespace]
}

resource "null_resource" "wait_for_elasticsearch" {
  count = var.elasticsearch_backup_enabled ? 1 : 0
  #triggers = {
  #  always_run = timestamp()
  #}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
until kubectl exec ${local.client_code}-${local.onify_instance}-elasticsearch-0 -n ${kubernetes_namespace.customer_namespace.metadata.0.name} -- curl -s localhost:9200; do sleep 20; done
EOF
  }

  depends_on = [
    kubernetes_stateful_set.elasticsearch,
    kubernetes_service.elasticsearch,
    kubernetes_namespace.customer_namespace
  ]
}

resource "null_resource" "slm_policy" {
  count = var.elasticsearch_backup_enabled ? 1 : 0
  ## uncomment below for debugging, will always run
  #triggers = {
  #  always_run = timestamp()
  #}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
kubectl exec ${local.client_code}-${local.onify_instance}-elasticsearch-0 -n ${kubernetes_namespace.customer_namespace.metadata.0.name} -it -- curl -s \
 -X PUT \
 "http://${local.client_code}-${local.onify_instance}-elasticsearch.${kubernetes_namespace.customer_namespace.metadata.0.name}.svc.cluster.local:9200/_snapshot/backup_repo" \
 -H "Content-Type: application/json" -d '{
    "type": "fs",
    "settings": {
      "location": "/usr/share/elasticsearch/backup"
    }
  }'
EOF
  }
  depends_on = [
    null_resource.wait_for_elasticsearch,
    kubernetes_stateful_set.elasticsearch,
    kubernetes_service.elasticsearch,
    kubernetes_namespace.customer_namespace
  ]
}

resource "null_resource" "slm_policy_schedule" {
  count = var.elasticsearch_backup_enabled ? 1 : 0
  triggers = {
    #will only run if the schedule changes
    schedule = var.elasticsearch_backup_schedule
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
kubectl exec ${local.client_code}-${local.onify_instance}-elasticsearch-0 -n ${kubernetes_namespace.customer_namespace.metadata.0.name} -it -- curl -s \
  -X PUT "http://${local.client_code}-${local.onify_instance}-elasticsearch.${kubernetes_namespace.customer_namespace.metadata.0.name}.svc.cluster.local:9200/_slm/policy/daily-snapshot?pretty" -H "Content-Type: application/json" -d '{
  "schedule": "${var.elasticsearch_backup_schedule}",
  "name": "<daily-snapshot-{now/d}>",
  "repository": "backup_repo",
  "config": {
    "indices": ["*"],
    "ignore_unavailable": true,
    "include_global_state": false
  },
  "retention": {
    "expire_after": "30d",
    "min_count": 5,
    "max_count": 50
  }
}'
EOF
  }
  depends_on = [
    null_resource.slm_policy,
    kubernetes_stateful_set.elasticsearch,
    kubernetes_service.elasticsearch,
    kubernetes_namespace.customer_namespace
  ]
}