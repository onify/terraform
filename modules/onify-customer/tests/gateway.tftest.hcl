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
    condition     = length(kubernetes_deployment_v1.onify-hub-gateway) == 0 && length(kubernetes_service_v1.onify-hub-gateway) == 0
    error_message = "Existing Customer installations must not gain gateway resources by default."
  }
}

run "gateway_adds_only_its_own_workload_and_service" {
  command = plan

  variables {
    deployment_replicas     = 2
    onify_hub_gateway_image = "eu.gcr.io/onify-images/gateway:dev"
    onify_hub_gateway_envs  = { CLIENT_CODE = "example", PORT = "3000" }
  }

  assert {
    condition = (
      kubernetes_deployment_v1.onify-hub-gateway[0].metadata[0].name == "example-test-hub-gateway" &&
      kubernetes_deployment_v1.onify-hub-gateway[0].metadata[0].namespace == "example-test" &&
      kubernetes_deployment_v1.onify-hub-gateway[0].spec[0].replicas == "2" &&
      kubernetes_deployment_v1.onify-hub-gateway[0].spec[0].template[0].spec[0].image_pull_secrets[0].name == "onify-regcred" &&
      kubernetes_deployment_v1.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].image == "eu.gcr.io/onify-images/gateway:dev" &&
      tomap({
        for env in kubernetes_deployment_v1.onify-hub-gateway[0].spec[0].template[0].spec[0].container[0].env : env.name => env.value
      }) == tomap({ CLIENT_CODE = "example", PORT = "8686" })
    )
    error_message = "Hub Gateway must use the customer's namespace, image, credentials, replicas, and fixed port."
  }

  assert {
    condition = (
      kubernetes_service_v1.onify-hub-gateway[0].metadata[0].name == "example-test-hub-gateway" &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].type == "ClusterIP" &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].selector == kubernetes_deployment_v1.onify-hub-gateway[0].spec[0].template[0].metadata[0].labels &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].port[0].port == 8686 &&
      kubernetes_service_v1.onify-hub-gateway[0].spec[0].port[0].target_port == "hub-gateway"
    )
    error_message = "Only the internal Hub Gateway Service should expose the new workload on port 8686."
  }
}

run "reject_empty_image" {
  command = plan

  variables {
    onify_hub_gateway_image = " "
  }

  expect_failures = [var.onify_hub_gateway_image]
}
