mock_provider "kubernetes" {
  override_during = plan
}

mock_provider "null" {
  override_during = plan
}

variables {
  gcr_registry_keyfile = "tests/fixtures/keyfile.json"
  onify_app_image      = "example/citizen-app:root"
  onify_api_image      = "example/api:stable"
  onify_gateway_image  = "example/gateway:stable"
  onify_api_envs = {
    ONIFY_client_code     = "example"
    ONIFY_client_instance = "test"
  }
}

run "gateway_replaces_functions" {
  command = plan

  variables {
    ingress             = false
    deployment_replicas = 2
    onify_gateway_image = "eu.gcr.io/onify-images/gateway:dev"
    onify_gateway_envs = {
      NODE_ENV    = "development"
      PORT        = 3000
      CLIENT_CODE = "example"
    }
  }

  assert {
    condition = (
      kubernetes_deployment_v1.onify-gateway.metadata[0].name == "example-test-gateway" &&
      kubernetes_deployment_v1.onify-gateway.metadata[0].namespace == "example-test" &&
      kubernetes_deployment_v1.onify-gateway.spec[0].replicas == "2" &&
      kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].image_pull_secrets[0].name == "onify-regcred"
    )
    error_message = "The gateway must use the customer's namespace, replica count, and registry credentials."
  }

  assert {
    condition = (
      kubernetes_service_v1.onify-gateway.metadata[0].name == "onify-halo-gateway" &&
      kubernetes_service_v1.onify-gateway.metadata[0].namespace == "example-test" &&
      kubernetes_service_v1.onify-gateway.spec[0].type == "ClusterIP" &&
      kubernetes_service_v1.onify-gateway.spec[0].selector == kubernetes_deployment_v1.onify-gateway.spec[0].template[0].metadata[0].labels &&
      kubernetes_service_v1.onify-gateway.spec[0].port[0].port == 8686 &&
      kubernetes_service_v1.onify-gateway.spec[0].port[0].target_port == kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].port[0].name &&
      kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].port[0].container_port == 8686
    )
    error_message = "The internal Service must route port 8686 to Gateway port 8686."
  }

  assert {
    condition = (
      kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].image == "eu.gcr.io/onify-images/gateway:dev" &&
      tomap({
        for env in kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].env : env.name => env.value
      }) == tomap({ NODE_ENV = "development", PORT = "8686", CLIENT_CODE = "example" })
    )
    error_message = "Gateway must use its configured image and environment."
  }
}

run "gateway_works_for_another_customer" {
  command = plan

  variables {
    onify_gateway_image = "eu.gcr.io/onify-images/gateway:dev"
    service_name_prefix = "onify-citizen-"
    onify_api_envs = {
      ONIFY_client_code     = "another"
      ONIFY_client_instance = "prod"
    }
  }

  assert {
    condition = (
      kubernetes_deployment_v1.onify-gateway.metadata[0].namespace == "another-prod" &&
      kubernetes_service_v1.onify-gateway.metadata[0].name == "onify-citizen-gateway" &&
      tomap({
        for env in kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].env : env.name => env.value
      }) == tomap({ NODE_ENV = "production", PORT = "8686" })
    )
    error_message = "The gateway must follow each customer's namespace, use its default environment when omitted, and work with the Citizen app."
  }
}

run "custom_gateway_environment_is_passed_through" {
  command = plan

  variables {
    onify_gateway_image = "example/gateway:stable"
    onify_gateway_envs  = { NODE_ENV = "production" }
  }

  assert {
    condition = tomap({
      for env in kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].env : env.name => env.value
    }) == tomap({ NODE_ENV = "production", PORT = "8686" })
    error_message = "Gateway must keep custom environment variables and set its fixed port."
  }
}

run "reject_empty_image_references" {
  command = plan

  variables {
    onify_gateway_image = " "
  }

  expect_failures = [var.onify_gateway_image]
}

run "reject_invalid_service_prefix" {
  command = plan

  variables {
    service_name_prefix = "Citizen_"
  }

  expect_failures = [var.service_name_prefix]
}
