resource "kubernetes_namespace" "customer_namespace" {
  metadata {
    labels = var.namespace_labels
    name   = local.namespace
  }

  depends_on = [data.kubernetes_config_map_v1.environment]

  lifecycle {
    prevent_destroy = true
    precondition {
      condition = var.environment_profile == null || (
        can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", local.namespace)) && length("${local.namespace}-elasticsearch") <= 63 &&
        var.elasticsearch_address == null && !contains(keys(var.onify_api_envs), "ONIFY_db_elasticsearch_host") &&
        (var.runtime_secrets.api == null || length(setintersection(keys(var.onify_api_envs), local.credential_keys)) == 0)
      )
      error_message = "A managed environment requires a DNS-safe instance name, its own database, and a single source of API credentials."
    }
  }
}
