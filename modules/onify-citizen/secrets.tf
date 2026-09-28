resource "kubernetes_secret" "docker-onify" {
  metadata {
    name      = "onify-regcred"
    namespace = kubernetes_namespace.customer_namespace.metadata.0.name
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "eu.gcr.io" = {
          auth = base64encode("_json_key:${file(var.gcr_registry_keyfile)}")
        }
      }
    })
  }
  type       = "kubernetes.io/dockerconfigjson"
  depends_on = [kubernetes_namespace.customer_namespace]
}
