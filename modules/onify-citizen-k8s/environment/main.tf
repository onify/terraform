terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "< 2.25.0"
    }
  }
}

variable "namespace" { type = string }
variable "custom_hostname" { type = list(string) }

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
  dev1     = var.profile.domain == "dev1.onify.io"
  labels   = toset([for h in var.custom_hostname : h if !strcontains(h, ".")])
  legacy   = toset([for h in var.custom_hostname : h if local.dev1 && length(split(".", h)) == 2 && endswith(h, ".dev")])
  exact    = setsubtract(var.custom_hostname, setunion(local.labels, local.legacy))
  aliases = toset(concat(
    [for h in local.exact : trimsuffix(h, ".")],
    [for h in local.labels : "${h}.${var.profile.domain}"],
    [for h in local.legacy : "${trimsuffix(h, ".dev")}.${var.profile.domain}"],
    local.dev1 ? [for h in setunion([var.namespace], local.labels, local.legacy) : "${h}.onify.net"] : []
  ))
  # A fixed key lets installations migrate their existing primary route in state.
  hosts = merge({ primary = local.hostname }, { for h in local.aliases : h => h if h != local.hostname })
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
