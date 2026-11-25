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
      kubernetes_namespace.customer_namespace.metadata[0].name == "example-test" &&
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
  # Applying with the mock provider also tests destruction during test teardown.
  command = apply

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

run "use_cluster_profile" {
  command = plan
  variables {
    environment_profile   = "citizen-test"
    elasticsearch_address = null
    runtime_secrets       = {}
    onify_api_envs = {
      ONIFY_client_code          = "example", ONIFY_client_instance = "test"
      ONIFY_initialLicense       = "fixture", ONIFY_adminUser_password = "fixture"
      ONIFY_apiTokens_app_secret = "fixture", ONIFY_client_secret = "fixture"
    }
  }
  override_data {
    target = data.kubernetes_namespace.system[0]
    values = { metadata = { name = "kube-system", uid = "test-cluster" } }
  }
  override_data {
    target = data.kubernetes_config_map_v1.environment[0]
    values = { data = { "profile.json" = <<-JSON
      {
        "cluster_uid":"test-cluster", "domain":"test.example", "storage_class":"dynamic",
        "elasticsearch_image":"example/search:7", "gateway_name":"public", "gateway_namespace":"edge",
        "gateway_daemonset":"edge-proxy", "acme_account_secret":"acme", "additional_https_exclusions":[],
        "api_envs":{"NODE_ENV":"test"}
      }
    JSON
    } }
  }
  override_module {
    target          = module.environment[0]
    override_during = plan
    outputs         = { workload_namespace = "example-test", url = "https://example-test.test.example" }
  }
  assert {
    condition = (
      output.url == "https://example-test.test.example" && local.api_envs.NODE_ENV == "test" &&
      !contains(keys(local.api_envs), "ONIFY_client_secret") &&
      kubernetes_secret_v1.api_runtime[0].data.ONIFY_client_secret == "fixture"
    )
    error_message = "Load the cluster profile and store bootstrap credentials separately from pod settings."
  }
}

run "public_alias_requires_profile" {
  command = plan
  variables { custom_hostname = ["portal"] }
  expect_failures = [kubernetes_namespace.customer_namespace]
}

run "reject_invalid_hostname" {
  command = plan
  variables { custom_hostname = ["https://portal.example.se/api"] }
  expect_failures = [var.custom_hostname]
}
