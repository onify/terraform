resource "kubernetes_network_policy" "internal" {
  metadata {
    name      = "citizen-internal"
    namespace = var.namespace
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        pod_selector {}
      }
    }
    egress {
      to {
        pod_selector {}
      }
    }
    egress {
      to {
        namespace_selector { match_labels = { "kubernetes.io/metadata.name" = "kube-system" } }
        pod_selector { match_labels = { k8s-app = "kube-dns" } }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

data "kubernetes_resource" "gateway" {
  api_version = "apps/v1"
  kind        = "DaemonSet"
  metadata {
    name      = var.profile.gateway_daemonset
    namespace = local.edge
  }
}

resource "kubernetes_network_policy" "edge" {
  metadata {
    name      = "citizen-app-ingress"
    namespace = var.namespace
  }
  spec {
    pod_selector { match_labels = { app = "${var.namespace}-app" } }
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector { match_labels = { "kubernetes.io/metadata.name" = local.edge } }
        pod_selector { match_labels = data.kubernetes_resource.gateway.object.spec.selector.matchLabels }
      }
      ports {
        port     = "4000"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "external_https" {
  metadata {
    name      = "citizen-public-https"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_expressions {
        key      = "app"
        operator = "In"
        values   = [for role in ["api", "worker", "gateway"] : "${var.namespace}-${role}"]
      }
    }
    policy_types = ["Egress"]
    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = concat(["0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.0.2.0/24", "192.168.0.0/16", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "224.0.0.0/4", "240.0.0.0/4"], var.profile.additional_https_exclusions)
        }
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }
  }
}
