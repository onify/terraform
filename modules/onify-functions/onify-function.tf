resource "kubernetes_config_map" "functions" {
  metadata {
    name      = "${var.client_code}-${var.client_instance}-functions"
    namespace = "${var.client_code}-${var.client_instance}"
  }

  data = {
    WHOAMI_NAME = "APAN123"
  }
}

resource "kubernetes_stateful_set" "function" {
  metadata {
    name      = "${var.client_code}-${var.client_instance}-${var.name}"
    namespace = "${var.client_code}-${var.client_instance}"
    labels = {
      app  = "${var.client_code}-${var.client_instance}-${var.name}"
      name = "${var.client_code}-${var.client_instance}-${var.name}"
    }
  }
  spec {
    service_name = "${var.client_code}-${var.client_instance}-${var.name}"
    replicas     = 2
    selector {
      match_labels = {
        app  = "${var.client_code}-${var.client_instance}-${var.name}"
        task = "${var.client_code}-${var.client_instance}-${var.name}"
      }
    }
    template {
      metadata {
        labels = {
          app  = "${var.client_code}-${var.client_instance}-${var.name}"
          task = "${var.client_code}-${var.client_instance}-${var.name}"
        }
      }
      spec {
        image_pull_secrets {
          name = "onify-regcred"
        }
        container {
          image = var.image
          name  = "${var.client_code}-${var.client_instance}-${var.name}"
          port {
            name           = var.name 
            container_port = var.port 
          }
          dynamic "env" {
            for_each = var.envs
            content {
              name  = env.key
              value = env.value
            }
          }
          env_from {
            config_map_ref {
              name = "${var.client_code}-${var.client_instance}-functions"
            }
          }
      }
    }
  }
}
}

resource "kubernetes_service" "function" {
  metadata {
    name      = "${var.client_code}-${var.client_instance}-${var.name}"
    namespace = "${var.client_code}-${var.client_instance}"
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }
  spec {
    selector = {
      app  = "${var.client_code}-${var.client_instance}-${var.name}"
      task = "${var.client_code}-${var.client_instance}-${var.name}"
    }
    port {
      name     = var.name
      port     = var.port 
      protocol = "TCP"
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "function" {
  wait_for_load_balancer = false
  metadata {
    name      = "${var.client_code}-${var.client_instance}-${var.name}"
    namespace = "${var.client_code}-${var.client_instance}"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-${var.tls}"
    }
  }
  spec {
    tls {
      hosts = ["${var.client_code}-${var.client_instance}-${var.name}.${var.external_dns_domain}"]
      secret_name = "tls-secret-${var.name}-${var.tls}"
    }
    ingress_class_name = "nginx"
    rule {
    host = "${var.client_code}-${var.client_instance}-${var.name}.${var.external_dns_domain}"
      http {
        path {
          backend {
            service {
              name = "${var.client_code}-${var.client_instance}-${var.name}"
            port {
              number = var.port 
            }
            } 
          }
        }
      }
    }
  }
}
