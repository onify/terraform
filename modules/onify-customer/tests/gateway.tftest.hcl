mock_provider "kubernetes" {
  override_during = plan
}

mock_provider "null" {
  override_during = plan
}

variables {
  gcr_registry_keyfile = "tests/fixtures/keyfile.json"
  onify_hub_api_envs = {
    ONIFY_client_code     = "example"
    ONIFY_client_instance = "test"
  }
}

run "gateway_is_disabled_by_default" {
  command = plan

  assert {
    condition = (
      length(kubernetes_stateful_set.onify-hub-gateway) == 0 &&
      length(kubernetes_service_v1.onify-hub-gateway) == 0 &&
      length(kubernetes_service_v1.onify-hub-gateway-alias) == 0 &&
      length(kubernetes_ingress_v1.onify-hub-gateway) == 0
    )
    error_message = "Existing Customer installations must not gain gateway resources by default."
  }
}

run "gateway_uses_functions_workload_and_service_pattern" {
  command = plan

  variables {
    deployment_replicas     = 2
    onify_hub_gateway_image = "eu.gcr.io/onify-images/gateway:dev"
    onify_hub_gateway_envs  = { CLIENT_CODE = "example", PORT = "3000" }
  }

  assert {
    condition = (
      kubernetes_stateful_set.onify-hub-gateway[0].metadata[0].name == "example-test-hub-gateway" &&
      kubernetes_stateful_set.onify-hub-gateway[0].metadata[0].namespace == "example-test" &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].service_name == kubernetes_service_v1.onify-hub-gateway[0].metadata[0].name &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].replicas == "2" &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].selector[0].match_labels == kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].metadata[0].labels &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].image_pull_secrets[0].name == "onify-regcred" &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].image == "eu.gcr.io/onify-images/gateway:dev" &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].image_pull_policy == "Always" &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].port[0].name == "hub-gateway" &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].port[0].container_port == 8686 &&
      tomap({
        for env in kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].env : env.name => env.value
      }) == tomap({ CLIENT_CODE = "example", PORT = "8686" })
    )
    error_message = "Hub Gateway must use the customer's namespace, image, credentials, replicas, and fixed port."
  }

  assert {
    condition = (
      kubernetes_service_v1.onify-hub-gateway[0].metadata[0].name == "example-test-hub-gateway" &&
      kubernetes_service_v1.onify-hub-gateway[0].metadata[0].namespace == kubernetes_stateful_set.onify-hub-api.metadata[0].namespace &&
      kubernetes_service_v1.onify-hub-gateway[0].metadata[0].annotations == kubernetes_service.onify-hub-functions.metadata[0].annotations &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].type == "ClusterIP" &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].selector == kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].metadata[0].labels &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].port[0].port == 8686 &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].port[0].target_port == "hub-gateway"
    )
    error_message = "The primary Hub Gateway Service must select the StatefulSet on port 8686 in the API's namespace."
  }

  assert {
    condition = (
      kubernetes_service_v1.onify-hub-gateway-alias[0].metadata[0].name == "hub-gateway" &&
      kubernetes_service_v1.onify-hub-gateway-alias[0].metadata[0].namespace == kubernetes_stateful_set.onify-hub-api.metadata[0].namespace &&
      kubernetes_service_v1.onify-hub-gateway-alias[0].metadata[0].annotations == kubernetes_service.onify-hub-functions-alias.metadata[0].annotations &&
      kubernetes_service_v1.onify-hub-gateway-alias[0].spec[0].type == "ClusterIP" &&
      kubernetes_service_v1.onify-hub-gateway-alias[0].spec[0].selector == kubernetes_service_v1.onify-hub-gateway[0].spec[0].selector &&
      kubernetes_service_v1.onify-hub-gateway-alias[0].spec[0].port[0].port == 8686 &&
      kubernetes_service_v1.onify-hub-gateway-alias[0].spec[0].port[0].target_port == "hub-gateway" &&
      length(kubernetes_ingress_v1.onify-hub-gateway) == 0
    )
    error_message = "hub-gateway:8686 must expose the same workload as the primary Service and remain internal by default."
  }
}

run "gateway_supports_resources_and_external_routing_like_functions" {
  command = plan

  variables {
    onify_hub_gateway_image           = "eu.gcr.io/onify-images/gateway:dev"
    onify_hub_gateway_memory_limit    = "512Mi"
    onify_hub_gateway_cpu_limit       = "500m"
    onify_hub_gateway_memory_requests = "256Mi"
    onify_hub_gateway_cpu_requests    = "250m"
    onify_hub_gateway_external        = true
    onify_hub_functions_external      = true
    tls                               = "stage"
    external_dns_domain               = "example.com"
    custom_hostname                   = ["portal"]
  }

  assert {
    condition = (
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].resources[0].limits == tomap({ memory = "512Mi", cpu = "500m" }) &&
      kubernetes_stateful_set.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].resources[0].requests == tomap({ memory = "256Mi", cpu = "250m" })
    )
    error_message = "Gateway resource limits and requests must be configurable like Functions."
  }

  assert {
    condition = (
      kubernetes_ingress_v1.onify-hub-gateway[0].spec[0].ingress_class_name == kubernetes_ingress_v1.onify-hub-functions[0].spec[0].ingress_class_name &&
      kubernetes_ingress_v1.onify-hub-gateway[0].metadata[0].annotations == kubernetes_ingress_v1.onify-hub-functions[0].metadata[0].annotations &&
      {
        for rule in kubernetes_ingress_v1.onify-hub-gateway[0].spec[0].rule : rule.host => "${rule.http[0].path[0].backend[0].service[0].name}:${rule.http[0].path[0].backend[0].service[0].port[0].number}"
        } == {
        "example-test-hub-gateway.example.com" = "example-test-hub-gateway:8686"
        "portal-hub-gateway.example.com"       = "example-test-hub-gateway:8686"
      } &&
      {
        for tls in kubernetes_ingress_v1.onify-hub-gateway[0].spec[0].tls : one(tls.hosts) => tls.secret_name
        } == {
        "example-test-hub-gateway.example.com" = "tls-secret-hub-gateway-stage"
        "portal-hub-gateway.example.com"       = "tls-secret-hub-gateway-stage-custom-portal"
      }
    )
    error_message = "Gateway ingress must mirror Functions routing, issuer, and TLS for primary and custom hosts."
  }
}

run "gateway_tls_secret_can_be_overridden" {
  command = plan

  variables {
    onify_hub_gateway_image    = "eu.gcr.io/onify-images/gateway:dev"
    onify_hub_gateway_external = true
    onify_hub_gateway_tls      = "gateway-tls"
    custom_hostname            = ["portal"]
  }

  assert {
    condition     = length(kubernetes_ingress_v1.onify-hub-gateway[0].spec[0].tls) == 2 && alltrue([for tls in kubernetes_ingress_v1.onify-hub-gateway[0].spec[0].tls : tls.secret_name == "gateway-tls"])
    error_message = "A gateway TLS override must apply to both primary and custom hosts."
  }
}

run "global_ingress_switch_disables_gateway_ingress" {
  command = plan

  variables {
    onify_hub_gateway_image    = "eu.gcr.io/onify-images/gateway:dev"
    onify_hub_gateway_external = true
    ingress                    = false
  }

  assert {
    condition     = length(kubernetes_ingress_v1.onify-hub-gateway) == 0 && length(kubernetes_service_v1.onify-hub-gateway-alias) == 1
    error_message = "Disabling ingress must keep the gateway internal."
  }
}

run "external_gateway_requires_an_image" {
  command = plan

  variables {
    onify_hub_gateway_external = true
  }

  assert {
    condition     = length(kubernetes_ingress_v1.onify-hub-gateway) == 0
    error_message = "Gateway ingress must not be created without a gateway workload."
  }
}

run "reject_empty_image" {
  command = plan

  variables {
    onify_hub_gateway_image = " "
  }

  expect_failures = [var.onify_hub_gateway_image]
}
