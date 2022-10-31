resource "kubernetes_namespace" "customer_namespace" {
    metadata {
        name = "${local.client_code}-${local.onify_instance}"
    }
}