terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "< 2.25.0"
    }
  }
}

variable "namespace" { type = string }

variable "backend" {
  type = object({ name = string, namespace = string })
}

variable "profile" {
  type = object({
    domain                      = string
    gateway_namespace           = string
    gateway_name                = string
    gateway_daemonset           = string
    acme_account_secret         = string
    storage_class               = string
    elasticsearch_image         = string
    additional_https_exclusions = list(string)
  })
}

locals {
  hostname = "${var.namespace}.${var.profile.domain}"
}

# Gate pod creation on the database and isolation policies. Routing also depends on the app.
output "workload_namespace" {
  value      = var.namespace
  depends_on = [kubernetes_stateful_set_v1.database, kubernetes_network_policy.edge, kubernetes_network_policy.external_https]
}

output "url" {
  value      = "https://${local.hostname}"
  depends_on = [kubernetes_manifest.https, kubernetes_manifest.redirect]
}
