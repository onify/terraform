resource "kubernetes_secret" "registry" {
  count = var.gcr_registry_keyfile == null ? 0 : 1

  metadata {
    name      = "onify-regcred"
    namespace = local.workload_namespace
  }

  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "eu.gcr.io" = {
          auth = base64encode("_json_key:${file(var.gcr_registry_keyfile)}")
        }
      }
    })
  }
}
