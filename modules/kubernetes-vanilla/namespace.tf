resource "kubernetes_namespace" "customer_namespace" {
    metadata {
        name = "${local.name}"
    }
}