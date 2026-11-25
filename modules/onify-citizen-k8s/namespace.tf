variable "create_namespace" {
  description = "Create the instance namespace. Set to false when the caller provisions it before this module."
  type        = bool
  default     = true
  nullable    = false
}

moved {
  from = kubernetes_namespace.customer_namespace
  to   = kubernetes_namespace.customer_namespace[0]
}

locals {
  workload_namespace = var.create_namespace ? kubernetes_namespace.customer_namespace[0].metadata[0].name : local.namespace
}

resource "kubernetes_namespace" "customer_namespace" {
  count = var.create_namespace ? 1 : 0

  metadata {
    labels = var.namespace_labels
    name   = local.namespace
  }

  lifecycle {
    prevent_destroy = true
  }
}
