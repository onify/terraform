mock_provider "kubernetes" {
  override_during = plan
}

variables {
  onify_api_image       = "example/api:dev"
  onify_worker_image    = "example/api:dev"
  onify_app_image       = "example/app:dev"
  onify_gateway_image   = "example/gateway:dev"
  elasticsearch_address = "http://existing-search:9200"
  onify_api_envs = {
    ONIFY_client_code     = "example"
    ONIFY_client_instance = "test"
    NODE_ENV              = "development"
  }
  runtime_secrets = { api = "api-runtime", gateway = "gateway-runtime" }
}

run "plan_existing_cluster" {
  command = plan

  assert {
    condition = (
      kubernetes_namespace.customer_namespace[0].metadata[0].name == "example-test" &&
      kubernetes_config_map.onify-api.data.ONIFY_db_elasticsearch_host == var.elasticsearch_address &&
      alltrue([for pod in [
        kubernetes_stateful_set.onify-api.spec[0].template[0].spec[0],
        kubernetes_stateful_set.onify-worker.spec[0].template[0].spec[0]
        ] : pod.container[0].env_from[0].secret_ref[0].name == "api-runtime" &&
        pod.container[0].env_from[1].config_map_ref[0].name == "example-test-api" &&
        tomap({ for env in pod.container[0].env : env.name => env.value }) == var.onify_api_envs
      ]) &&
      length(kubernetes_stateful_set.onify-app.spec[0].template[0].spec[0].container[0].env_from) == 0
    )
    error_message = "API and worker must share the public settings, Secret and database target."
  }

  assert {
    condition = (
      length(kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].volume) == 0 &&
      length(kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].volume_mount) == 0 &&
      kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0].container[0].env_from[0].secret_ref[0].name == "gateway-runtime" &&
      length(kubernetes_secret.registry) == 0
    )
    error_message = "The gateway must run without infra-managed files and optional registry credentials."
  }
}

run "instance_service_and_registry_credentials" {
  command = plan

  variables {
    elasticsearch_address = null
    gcr_registry_keyfile  = "tests/fixtures/keyfile.json"
  }

  assert {
    condition = (
      kubernetes_config_map.onify-api.data.ONIFY_db_elasticsearch_host == "http://example-test-elasticsearch:9200" &&
      keys(jsondecode(kubernetes_secret.registry[0].data[".dockerconfigjson"]).auths) == ["eu.gcr.io"] &&
      alltrue([for pod in [
        kubernetes_stateful_set.onify-api.spec[0].template[0].spec[0],
        kubernetes_stateful_set.onify-worker.spec[0].template[0].spec[0],
        kubernetes_stateful_set.onify-app.spec[0].template[0].spec[0],
        kubernetes_deployment_v1.onify-gateway.spec[0].template[0].spec[0]
      ] : pod.image_pull_secrets[0].name == "onify-regcred"])
    )
    error_message = "Use the instance Elasticsearch Service and attach Google registry credentials to all four workloads."
  }
}

run "caller_owned_namespace" {
  command = plan
  variables {
    create_namespace = false
  }
  assert {
    condition = (
      length(kubernetes_namespace.customer_namespace) == 0 &&
      kubernetes_stateful_set.onify-api.metadata[0].namespace == "example-test" &&
      kubernetes_service.onify-app.metadata[0].namespace == "example-test"
    )
    error_message = "Use the existing instance namespace for workloads and services."
  }
}
