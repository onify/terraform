locals {
  edge      = var.profile.gateway_namespace
  group     = "gateway.networking.k8s.io"
  edge_name = "citizen-${var.namespace}"
  listener_names = { for key, host in local.hosts : key => (
    key == "primary" ? local.edge_name : "citizen-${substr(sha256("${var.namespace}/${host}"), 0, 20)}"
  ) }
  parents = { for key, name in local.listener_names : key => { group = local.group, kind = "ListenerSet", name = name } }
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
        alltrue([for l in self.object.spec.listeners : !try(contains(values(local.hosts), l.hostname), false)])
      )
      error_message = "The public Gateway must accept same-namespace ListenerSets and have all requested hostnames available."
    }
  }
}

data "kubernetes_resources" "listeners" {
  api_version = "${local.group}/v1"
  kind        = "ListenerSet"
  namespace   = local.edge
}

resource "kubernetes_manifest" "listeners" {
  for_each = local.hosts
  manifest = {
    apiVersion = "${local.group}/v1", kind = "ListenerSet"
    metadata   = { name = local.listener_names[each.key], namespace = local.edge }
    spec = {
      parentRef = { group = local.group, kind = "Gateway", name = var.profile.gateway_name }
      listeners = [
        { name = "http", hostname = each.value, protocol = "HTTP", port = 80, allowedRoutes = { namespaces = { from = "Same" } } },
        { name = "https", hostname = each.value, protocol = "HTTPS", port = 443, allowedRoutes = { namespaces = { from = "Same" } },
        tls = { mode = "Terminate", certificateRefs = [{ group = "", kind = "Secret", name = local.listener_names[each.key] }] } }
      ]
    }
  }
  lifecycle {
    precondition {
      condition = alltrue(flatten([for ls in data.kubernetes_resources.listeners.objects : [
        for l in ls.spec.listeners : try(l.hostname, null) != each.value
      ] if ls.metadata.name != local.listener_names[each.key]]))
      error_message = "Another ListenerSet already serves ${each.value}."
    }
    precondition {
      condition     = length(each.value) <= 253
      error_message = "The expanded hostname ${each.value} exceeds 253 characters."
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
      solvers = [for key, host in local.hosts : {
        selector = { dnsNames = [host] }
        http01 = { gatewayHTTPRoute = {
          serviceType = "ClusterIP", parentRefs = [merge(local.parents[key], { namespace = local.edge, sectionName = "http" })]
        } }
      }]
    } }
  }
  depends_on = [kubernetes_manifest.listeners]
}

resource "kubernetes_manifest" "certificate" {
  for_each = local.hosts
  manifest = {
    apiVersion = "cert-manager.io/v1", kind = "Certificate"
    metadata   = { name = local.listener_names[each.key], namespace = local.edge }
    spec = {
      secretName            = local.listener_names[each.key], dnsNames = [each.value]
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
  for_each = local.hosts
  manifest = {
    apiVersion = "${local.group}/v1", kind = "HTTPRoute"
    metadata   = { name = local.listener_names[each.key], namespace = local.edge }
    spec = {
      hostnames  = [each.value]
      parentRefs = [merge(local.parents[each.key], { sectionName = "https" })]
      rules = [{ matches = [{ path = { type = "PathPrefix", value = "/" } }], backendRefs = [{
        group = "", kind = "Service", name = var.backend.name, namespace = var.backend.namespace, port = 4000
      }] }]
    }
  }
  depends_on = [kubernetes_manifest.grant, kubernetes_manifest.certificate]
}

resource "kubernetes_manifest" "redirect" {
  for_each = local.hosts
  manifest = {
    apiVersion = "${local.group}/v1", kind = "HTTPRoute"
    metadata   = { name = "${local.listener_names[each.key]}-http", namespace = local.edge }
    spec = {
      hostnames  = [each.value]
      parentRefs = [merge(local.parents[each.key], { sectionName = "http" })]
      rules      = [{ filters = [{ type = "RequestRedirect", requestRedirect = { scheme = "https", statusCode = 301 } }] }]
    }
  }
  depends_on = [kubernetes_manifest.https]
}

moved {
  from = kubernetes_manifest.listeners
  to   = kubernetes_manifest.listeners["primary"]
}
moved {
  from = kubernetes_manifest.certificate
  to   = kubernetes_manifest.certificate["primary"]
}
moved {
  from = kubernetes_manifest.https
  to   = kubernetes_manifest.https["primary"]
}
moved {
  from = kubernetes_manifest.redirect
  to   = kubernetes_manifest.redirect["primary"]
}
