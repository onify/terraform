resource "kubernetes_namespace" "customer_namespace" {
  metadata {
    name = "${local.client_code}-${local.onify_instance}"
  }

  lifecycle {
    precondition {
      condition     = !var.helix_only || var.helix
      error_message = "helix_only requires helix = true."
    }
  }
}
