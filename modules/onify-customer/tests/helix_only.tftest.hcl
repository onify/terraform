mock_provider "kubernetes" {
  override_during = plan
}

mock_provider "null" {
  override_during = plan
}

run "hybrid_is_the_default" {
  command = plan

  module {
    source = "./helix"
  }

  variables {
    custom_hostname      = ["portal"]
    external_dns_domain  = "example.com"
    onify_app_helix_envs = { ONIFY_API_URL_INTERNAL = "http://caller-owned" }
  }

  assert {
    condition     = length(kubernetes_stateful_set.onify-hub-app) == 1
    error_message = "Hybrid mode must retain the legacy app StatefulSet."
  }

  assert {
    condition     = length(kubernetes_service.onify-hub-app) == 1
    error_message = "Hybrid mode must retain the legacy app service."
  }

  assert {
    condition = {
      for route in kubernetes_ingress_v1.onify-helix-app[0].spec[0].rule[0].http[0].path : route.path => "${route.backend[0].service[0].name}:${route.backend[0].service[0].port[0].number}"
      } == {
      "/"      = "xxxx-xxxx-hub-app:3000"
      "/helix" = "xxxx-xxxx-helix-app:4000"
    }
    error_message = "Hybrid mode must keep exactly / on the legacy app and /helix on Helix."
  }

  assert {
    condition = (
      kubernetes_ingress_v1.onify-helix-app[0].spec[0].rule[1].host == "portal.example.com" &&
      {
        for route in kubernetes_ingress_v1.onify-helix-app[0].spec[0].rule[1].http[0].path : route.path => "${route.backend[0].service[0].name}:${route.backend[0].service[0].port[0].number}"
        } == {
        "/"      = "xxxx-xxxx-hub-app:3000"
        "/helix" = "xxxx-xxxx-helix-app:4000"
      }
    )
    error_message = "Hybrid custom-host routing must match the primary-host contract."
  }

  assert {
    condition = one([
      for value in kubernetes_stateful_set.onify-helix-app.spec[0].template[0].spec[0].container[0].env : value.value
      if value.name == "ONIFY_API_URL_INTERNAL"
    ]) == "http://caller-owned"
    error_message = "Hybrid mode must not inject or overwrite the root-proxy-only upstream variable."
  }
}

run "helix_only_removes_legacy_app_and_owns_both_paths" {
  command = plan

  module {
    source = "./helix"
  }

  variables {
    helix_only           = true
    custom_hostname      = ["portal"]
    external_dns_domain  = "example.com"
    onify_app_helix_envs = { ONIFY_API_URL_INTERNAL = "http://invalid-override" }
  }

  assert {
    condition     = length(kubernetes_stateful_set.onify-hub-app) == 0
    error_message = "Helix-only mode must not deploy the legacy app StatefulSet."
  }

  assert {
    condition     = length(kubernetes_service.onify-hub-app) == 0
    error_message = "Helix-only mode must not deploy the legacy app service."
  }

  assert {
    condition = {
      for route in kubernetes_ingress_v1.onify-helix-app[0].spec[0].rule[0].http[0].path : route.path => "${route.backend[0].service[0].name}:${route.backend[0].service[0].port[0].number}"
      } == {
      "/"      = "xxxx-xxxx-helix-app:4000"
      "/helix" = "xxxx-xxxx-helix-app:4000"
    }
    error_message = "Helix-only primary-host routing must contain exactly / and /helix on the Helix service."
  }

  assert {
    condition = (
      kubernetes_ingress_v1.onify-helix-app[0].spec[0].rule[1].host == "portal.example.com" &&
      {
        for route in kubernetes_ingress_v1.onify-helix-app[0].spec[0].rule[1].http[0].path : route.path => "${route.backend[0].service[0].name}:${route.backend[0].service[0].port[0].number}"
        } == {
        "/"      = "xxxx-xxxx-helix-app:4000"
        "/helix" = "xxxx-xxxx-helix-app:4000"
      }
    )
    error_message = "Helix-only custom-host routing must match the primary-host contract."
  }

  assert {
    condition = (
      length([
        for value in kubernetes_stateful_set.onify-helix-app.spec[0].template[0].spec[0].container[0].env : value
        if value.name == "ONIFY_API_URL_INTERNAL"
      ]) == 1 &&
      one([
        for value in kubernetes_stateful_set.onify-helix-app.spec[0].template[0].spec[0].container[0].env : value.value
        if value.name == "ONIFY_API_URL_INTERNAL"
      ]) == "http://xxxx-xxxx-hub-api:8181"
    )
    error_message = "The module must inject exactly one authoritative root proxy upstream API URL."
  }
}

run "helix_submodule_rejects_invalid_mode" {
  command = plan

  module {
    source = "./helix"
  }

  variables {
    helix      = false
    helix_only = true
  }

  expect_failures = [kubernetes_stateful_set.onify-helix-app]
}

run "public_module_passes_helix_only" {
  command = plan

  variables {
    helix                = true
    helix_only           = true
    gcr_registry_keyfile = "tests/fixtures/keyfile.json"
  }

  assert {
    condition     = length(module.helix) == 1 && length(module.hub) == 0 && module.helix[0].helix_only
    error_message = "The public module must select the Helix submodule and pass helix_only through."
  }
}

run "public_module_supports_legacy_only" {
  command = plan

  variables {
    helix                = false
    helix_only           = false
    gcr_registry_keyfile = "tests/fixtures/keyfile.json"
  }

  assert {
    condition     = length(module.helix) == 0 && length(module.hub) == 1
    error_message = "Legacy-only mode must select only the Hub submodule."
  }
}

run "helix_only_requires_helix" {
  command = plan

  variables {
    helix                = false
    helix_only           = true
    gcr_registry_keyfile = "tests/fixtures/keyfile.json"
  }

  expect_failures = [kubernetes_namespace.customer_namespace]
}
