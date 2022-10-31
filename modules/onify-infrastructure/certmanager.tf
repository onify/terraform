resource "helm_release" "cert_manager" {
  name  = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  create_namespace = true
  version    = "v1.9.1"
  namespace  = "cert-manager"
  provisioner "local-exec" {
        command = "sleep 10"
  }
  set {
    name  = "startupapicheck.timeout"
    value = "5m"
  }
  set {
    name  = "installCRDs"
    value = true 
  }
}


resource "kubectl_manifest" "cluster_issuer_letsencrypt_prod" {
  depends_on = [ helm_release.cert_manager ]
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
#change to your email
    email: hello@onify.io
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
          ingressTemplate:
            metadata:
              annotations:
                kubernetes.io/ingress.class: "public"

YAML
}

resource "kubectl_manifest" "cluster_issuer_letsencrypt_staging" {
  depends_on = [ helm_release.cert_manager ]
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
#change to your email
    email: hello@onify.io
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
          ingressTemplate:
            metadata:
              annotations:
                kubernetes.io/ingress.class: "public"
YAML
}