mock_provider "kubernetes" {
  override_during = plan
  mock_data "kubernetes_resource" {
    defaults = { object = { spec = {
      allowedListeners = { namespaces = { from = "Same" } }
      listeners        = []
      selector         = { matchLabels = { app = "edge" } }
    } } }
  }
  mock_data "kubernetes_resources" {
    defaults = { objects = [] }
  }
}

variables {
  namespace       = "sok-dev"
  backend         = { name = "onify-citizen-app", namespace = "sok-dev" }
  custom_hostname = []
  profile = {
    domain                      = "dev1.onify.io"
    gateway_namespace           = "edge"
    gateway_name                = "public"
    gateway_daemonset           = "nginx"
    acme_account_secret         = "account"
    storage_class               = "dynamic"
    elasticsearch_image         = "example/search:7"
    additional_https_exclusions = []
  }
}

run "dev1_default_hostnames" {
  command = plan
  module { source = "./environment" }
  assert {
    condition     = toset(values(local.hosts)) == toset(["sok-dev.dev1.onify.io", "sok-dev.onify.net"]) && output.url == "https://sok-dev.dev1.onify.io"
    error_message = "The dev1 profile must serve both automatic hostnames and keep the primary URL."
  }
}

run "sokigo_and_custom_domains" {
  command = apply
  module { source = "./environment" }
  variables {
    custom_hostname = ["nacka.dev", "norrtalje.dev", "portal", "portal.example.se", "portal.dev.", "nacka.dev", "sok-dev.onify.net"]
  }
  assert {
    condition = toset(values(local.hosts)) == toset([
      "sok-dev.dev1.onify.io", "sok-dev.onify.net", "nacka.dev1.onify.io", "nacka.dev.onify.net",
      "norrtalje.dev1.onify.io", "norrtalje.dev.onify.net", "portal.dev1.onify.io", "portal.onify.net",
      "portal.example.se", "portal.dev"
    ])
    error_message = "Preserve historical Sokigo aliases, standalone domains and deduplicated routes."
  }
  assert {
    condition = alltrue([for key, host in local.hosts : (
      kubernetes_manifest.listeners[key].manifest.spec.listeners[0].hostname == host &&
      kubernetes_manifest.listeners[key].manifest.spec.listeners[1].hostname == host &&
      kubernetes_manifest.listeners[key].manifest.spec.listeners[1].tls.certificateRefs[0].name == kubernetes_manifest.certificate[key].manifest.spec.secretName &&
      kubernetes_manifest.certificate[key].manifest.spec.dnsNames[0] == host &&
      kubernetes_manifest.https[key].manifest.spec.hostnames[0] == host &&
      kubernetes_manifest.https[key].manifest.spec.parentRefs[0].name == kubernetes_manifest.listeners[key].manifest.metadata.name &&
      kubernetes_manifest.https[key].manifest.spec.rules[0].backendRefs[0].name == var.backend.name &&
      kubernetes_manifest.https[key].manifest.spec.rules[0].backendRefs[0].port == 4000 &&
      kubernetes_manifest.redirect[key].manifest.spec.hostnames[0] == host &&
      kubernetes_manifest.redirect[key].manifest.spec.rules[0].filters[0].requestRedirect.scheme == "https"
    )])
    error_message = "Each host needs its own TLS listener, matching certificate, app backend and HTTPS redirect."
  }
}
