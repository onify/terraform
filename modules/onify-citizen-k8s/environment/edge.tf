locals {
  edge      = var.profile.gateway_namespace
  group     = "gateway.networking.k8s.io"
  edge_name = "citizen-${var.namespace}"
  parent    = { group = local.group, kind = "ListenerSet", name = local.edge_name }
}

data "kubernetes_resource" "public" {
  api_version = "${local.group}/v1"
  kind        = "Gateway"
  metadata {
    name      = var.profile.gateway_name
    namespace = local.edge
  }
  lifecycle {
    postcondition {
      condition = (
        self.object.spec.allowedListeners.namespaces.from == "Same" &&
        alltrue([for l in self.object.spec.listeners : try(l.hostname, null) != local.hostname])
      )
      error_message = "The public Gateway must accept same-namespace ListenerSets and have this hostname available."
    }
  }
}

data "kubernetes_resources" "listeners" {
  api_version = "${local.group}/v1"
  kind        = "ListenerSet"
  namespace   = local.edge
}

resource "kubernetes_manifest" "listeners" {
  manifest = {
    apiVersion = "${local.group}/v1", kind = "ListenerSet"
    metadata   = { name = local.edge_name, namespace = local.edge }
    spec = {
      parentRef = { group = local.group, kind = "Gateway", name = var.profile.gateway_name }
      listeners = [
        { name = "http", hostname = local.hostname, protocol = "HTTP", port = 80, allowedRoutes = { namespaces = { from = "Same" } } },
        { name = "https", hostname = local.hostname, protocol = "HTTPS", port = 443, allowedRoutes = { namespaces = { from = "Same" } },
        tls = { mode = "Terminate", certificateRefs = [{ group = "", kind = "Secret", name = local.edge_name }] } }
      ]
    }
  }
  lifecycle {
    precondition {
      condition = alltrue(flatten([for ls in data.kubernetes_resources.listeners.objects : [
        for l in ls.spec.listeners : try(l.hostname, null) != local.hostname
      ] if ls.metadata.name != local.edge_name]))
      error_message = "Another ListenerSet already serves the requested Citizen hostname."
    }
  }
  depends_on = [data.kubernetes_resource.public]
}

resource "kubernetes_manifest" "issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1", kind = "Issuer"
    metadata   = { name = local.edge_name, namespace = local.edge }
    spec = { acme = {
      server                      = "https://acme-v02.api.letsencrypt.org/directory"
      privateKeySecretRef         = { name = var.profile.acme_account_secret }
      disableAccountKeyGeneration = true
      solvers = [{ http01 = { gatewayHTTPRoute = {
        serviceType = "ClusterIP", parentRefs = [merge(local.parent, { namespace = local.edge, sectionName = "http" })]
      } } }]
    } }
  }
  depends_on = [kubernetes_manifest.listeners]
}

resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1", kind = "Certificate"
    metadata   = { name = local.edge_name, namespace = local.edge }
    spec = {
      secretName            = local.edge_name, dnsNames = [local.hostname]
      issuerRef             = { group = "cert-manager.io", kind = "Issuer", name = local.edge_name }
      privateKey            = { algorithm = "ECDSA", size = 256, rotationPolicy = "Always" }
      renewBeforePercentage = 33
    }
  }
  wait {
    condition {
      type   = "Ready"
      status = "True"
    }
  }
  timeouts { create = "10m" }
  depends_on = [kubernetes_manifest.issuer]
}

resource "kubernetes_manifest" "grant" {
  manifest = {
    apiVersion = "${local.group}/v1", kind = "ReferenceGrant"
    metadata   = { name = "citizen-app", namespace = var.namespace }
    spec = {
      from = [{ group = local.group, kind = "HTTPRoute", namespace = local.edge }]
      to   = [{ group = "", kind = "Service", name = "onify-citizen-app" }]
    }
  }
}

resource "kubernetes_manifest" "https" {
  manifest = {
    apiVersion = "${local.group}/v1", kind = "HTTPRoute"
    metadata   = { name = local.edge_name, namespace = local.edge }
    spec = {
      hostnames  = [local.hostname]
      parentRefs = [merge(local.parent, { sectionName = "https" })]
      rules = [{ matches = [{ path = { type = "PathPrefix", value = "/" } }], backendRefs = [{
        group = "", kind = "Service", name = var.backend.name, namespace = var.backend.namespace, port = 4000
      }] }]
    }
  }
  depends_on = [kubernetes_manifest.grant, kubernetes_manifest.certificate]
}

resource "kubernetes_manifest" "redirect" {
  manifest = {
    apiVersion = "${local.group}/v1", kind = "HTTPRoute"
    metadata   = { name = "${local.edge_name}-http", namespace = local.edge }
    spec = {
      hostnames  = [local.hostname]
      parentRefs = [merge(local.parent, { sectionName = "http" })]
      rules      = [{ filters = [{ type = "RequestRedirect", requestRedirect = { scheme = "https", statusCode = 301 } }] }]
    }
  }
  depends_on = [kubernetes_manifest.https]
}
