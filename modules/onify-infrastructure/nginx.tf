resource "helm_release" "nginx" {
  name  = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  create_namespace = true
  namespace  = "ingress"

  set {
    name  = "controller.config.proxy-body-size"
    value = "100m"
  }
  set {
    name  = "controller.config.enable-underscores-in-headers"
    value = "true"
  }
}
