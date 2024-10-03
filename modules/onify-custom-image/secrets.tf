resource "kubernetes_secret" "onify-custom-image" {
  metadata {
    name      = "${var.client_code}-${var.client_instance}-regcred"
    namespace = "${var.client_code}-${var.client_instance}"
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "eu.gcr.io": {
      "auth": "${base64encode("_json_key:${file("${var.gcr_registry_keyfile}")}")}"
    },
    "ghcr.io": {
      "auth": "${base64encode("${var.ghcr_registry_username}:${var.ghcr_registry_password}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}
