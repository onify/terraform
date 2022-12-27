resource "helm_release" "nginx" {
  name  = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  create_namespace = true
  namespace  = "ingress"

  #  set {
  #  name  = "controller.ingressClassResource.name"
  #  value = "public"
  #}
}
