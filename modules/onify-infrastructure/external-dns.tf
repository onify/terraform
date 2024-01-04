resource "kubernetes_service_account" "external-dns" {
  count = var.gke ? 1 : 0
  metadata {
    name = "external-dns"
  }
}

resource "kubernetes_cluster_role" "external-dns" {
  count = var.gke ? 1 : 0
  metadata {
    name = "external-dns"
  }
  rule {
    api_groups = [""]
    resources  = ["services","endpoints","pods"]
    verbs      = ["get","watch","list"]
  }
  rule {
    api_groups = ["extensions","networking.k8s.io"] 
    resources  = ["ingresses"]
    verbs      = ["get","watch","list"]
  }
  rule {
    api_groups = [""] 
    resources  = ["nodes"]
    verbs      = ["list"]
  }
}

resource "kubernetes_cluster_role_binding" "external-dns" {
  count = var.gke ? 1 : 0
  metadata {
    name = "external-dns-viewer"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "external-dns"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "external-dns"
    namespace = "default"
    api_group = ""
  }
}

resource "kubernetes_deployment" "external-dns" {
  count = var.gke ? 1 : 0
  metadata {
    name = "external-dns"
  }
  spec {
    strategy {
      type = "Recreate"
    }
    selector {
      match_labels = {
        app = "external-dns"
      }
    }
    template {
      metadata {
        labels = {
          app = "external-dns"
        }
      }
      spec {
        service_account_name = "external-dns"
        container {
          image = "k8s.gcr.io/external-dns/external-dns:v0.8.0"
          name  = "external-dns"
          args = ["--source=service","--domain-filter=${var.external_dns_domain}","--provider=google","--google-project=${var.gce_project_id}","--registry=txt","--txt-owner-id=onify_terraform"]
      }
    }
  }
  }
}