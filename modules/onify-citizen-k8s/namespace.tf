resource "kubernetes_namespace" "customer_namespace" {
  metadata {
    labels = var.namespace_labels
    name   = local.namespace
  }

  lifecycle {
    prevent_destroy = true
  }
}
