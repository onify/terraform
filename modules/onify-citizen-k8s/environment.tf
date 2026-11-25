variable "environment_profile" {
  description = "Optional name of a kube-system ConfigMap containing the cluster's Citizen profile.json."
  type        = string
  default     = null
}

data "kubernetes_namespace" "system" {
  count = var.environment_profile == null ? 0 : 1
  metadata { name = "kube-system" }
}

data "kubernetes_config_map_v1" "environment" {
  count = var.environment_profile == null ? 0 : 1
  metadata {
    name      = var.environment_profile
    namespace = "kube-system"
  }
  lifecycle {
    postcondition {
      condition     = jsondecode(self.data["profile.json"]).cluster_uid == data.kubernetes_namespace.system[0].metadata[0].uid
      error_message = "The Citizen profile must identify the connected cluster."
    }
  }
}

locals {
  profile            = var.environment_profile == null ? null : jsondecode(data.kubernetes_config_map_v1.environment[0].data["profile.json"])
  workload_namespace = var.environment_profile == null ? kubernetes_namespace.customer_namespace.metadata[0].name : module.environment[0].workload_namespace
  credential_keys    = ["ONIFY_initialLicense", "ONIFY_adminUser_password", "ONIFY_apiTokens_app_secret", "ONIFY_client_secret"]
  api_envs = var.environment_profile == null ? var.onify_api_envs : {
    for k, v in merge(try(local.profile.api_envs, {}), var.onify_api_envs) : k => v if !contains(local.credential_keys, k)
  }
  api_runtime_secrets = concat(var.runtime_secrets.api[*], kubernetes_secret_v1.api_runtime[*].metadata[0].name)
}

module "environment" {
  count     = var.environment_profile == null ? 0 : 1
  source    = "./environment"
  profile   = local.profile
  namespace = kubernetes_namespace.customer_namespace.metadata[0].name
  backend = {
    name      = kubernetes_service.onify-app.metadata[0].name
    namespace = kubernetes_stateful_set.onify-app.metadata[0].namespace
  }
}

resource "kubernetes_secret_v1" "api_runtime" {
  count = var.environment_profile != null && var.runtime_secrets.api == null ? 1 : 0
  metadata {
    generate_name = "citizen-api-"
    namespace     = kubernetes_namespace.customer_namespace.metadata[0].name
  }
  data      = { for k in local.credential_keys : k => lookup(var.onify_api_envs, k, "") }
  immutable = true
  lifecycle {
    create_before_destroy = true
    precondition {
      condition     = alltrue([for k in local.credential_keys : try(trimspace(var.onify_api_envs[k]) != "", false)])
      error_message = "Supply the four nonempty bootstrap credentials in onify_api_envs or reference runtime_secrets.api."
    }
  }
}

output "url" { value = one(module.environment[*].url) }
