mock_provider "kubernetes" {
  override_during = plan
}

mock_provider "null" {
  override_during = plan
}

variables {
  gcr_registry_keyfile  = "tests/fixtures/keyfile.json"
  onify_app_image       = "example/citizen-app:root"
  onify_api_image       = "example/api:stable"
  onify_functions_image = "example/functions:stable"
  onify_api_envs = {
    ONIFY_client_code     = "example"
    ONIFY_client_instance = "test"
  }
}

run "gateway_is_disabled_by_default" {
  command = plan

  assert {
    condition = (
      length(kubernetes_deployment_v1.onify-gateway) == 0 &&
      length(kubernetes_service_v1.onify-gateway) == 0
    )
    error_message = "Existing customers must not gain a Gateway Deployment or Service by default."
  }
}

run "environment_variables_alone_do_not_enable_gateway" {
  command = plan

  variables {
    onify_gateway_envs = { CLIENT_CODE = "example" }
  }

  assert {
    condition = (
      length(kubernetes_deployment_v1.onify-gateway) == 0 &&
      length(kubernetes_service_v1.onify-gateway) == 0
    )
    error_message = "Only setting a gateway image may enable its resources."
  }
}

run "gateway_is_independent_of_functions" {
  command = plan

  variables {
    ingress               = false
    deployment_replicas   = 2
    onify_functions_image = "eu.gcr.io/onify-images/citizen-functions:dev"
    onify_gateway_image   = "eu.gcr.io/onify-images/gateway:dev"
    onify_gateway_envs = {
      NODE_ENV    = "development"
      PORT        = 3000
      CLIENT_CODE = "example"
    }
  }

  assert {
    condition = (
      length(kubernetes_deployment_v1.onify-gateway) == 1 &&
      length(kubernetes_service_v1.onify-gateway) == 1 &&
      kubernetes_deployment_v1.onify-gateway[0].metadata[0].name == "example-test-gateway" &&
      kubernetes_deployment_v1.onify-gateway[0].metadata[0].namespace == "example-test" &&
      kubernetes_deployment_v1.onify-gateway[0].spec[0].replicas == "2" &&
      kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].spec[0].image_pull_secrets[0].name == "onify-regcred"
    )
    error_message = "The gateway must use the customer's namespace, replica count, and registry credentials."
  }

  assert {
    condition = (
      kubernetes_service_v1.onify-gateway[0].metadata[0].name == "example-test-gateway" &&
      kubernetes_service_v1.onify-gateway[0].metadata[0].namespace == "example-test" &&
      kubernetes_service_v1.onify-gateway[0].spec[0].type == "ClusterIP" &&
      kubernetes_service_v1.onify-gateway[0].spec[0].selector == kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].metadata[0].labels &&
      kubernetes_service_v1.onify-gateway[0].spec[0].selector != kubernetes_service.onify-functions.spec[0].selector &&
      kubernetes_service_v1.onify-gateway[0].spec[0].port[0].port == 8686 &&
      kubernetes_service_v1.onify-gateway[0].spec[0].port[0].target_port == kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].spec[0].container[0].port[0].name &&
      kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].spec[0].container[0].port[0].container_port == 8686
    )
    error_message = "The internal Service must route port 8686 to Gateway port 8686, independently of Functions and Ingress."
  }

  assert {
    condition = (
      kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].spec[0].container[0].image == "eu.gcr.io/onify-images/gateway:dev" &&
      tomap({
        for env in kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].spec[0].container[0].env : env.name => env.value
      }) == tomap({ NODE_ENV = "development", PORT = "8686", CLIENT_CODE = "example" }) &&
      kubernetes_stateful_set.onify-functions.spec[0].template[0].spec[0].container[0].image == "eu.gcr.io/onify-images/citizen-functions:dev" &&
      tomap({
        for env in kubernetes_stateful_set.onify-functions.spec[0].template[0].spec[0].container[0].env : env.name => env.value
      }) == tomap({ NODE_ENV = "production" })
    )
    error_message = "Gateway image and environment inputs must not change the existing Functions workload."
  }
}

run "gateway_works_for_another_customer" {
  command = plan

  variables {
    onify_gateway_image = "eu.gcr.io/onify-images/gateway:dev"
    onify_api_envs = {
      ONIFY_client_code     = "another"
      ONIFY_client_instance = "prod"
    }
  }

  assert {
    condition = (
      kubernetes_deployment_v1.onify-gateway[0].metadata[0].namespace == "another-prod" &&
      kubernetes_service_v1.onify-gateway[0].metadata[0].name == "another-prod-gateway" &&
      tomap({
        for env in kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].spec[0].container[0].env : env.name => env.value
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
      for env in kubernetes_deployment_v1.onify-gateway[0].spec[0].template[0].spec[0].container[0].env : env.name => env.value
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
