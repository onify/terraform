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
    ONIFY_client_instance = "prod"
  }
  onify_app_envs           = { ONIFY_API_URL_INTERNAL = "http://caller-owned" }
  onify_functions_external = true
  custom_hostname          = ["portal"]
}

run "app_owns_root_route" {
  command = plan

  assert {
    condition = (
      kubernetes_stateful_set.onify-app.metadata[0].name == "example-prod-app" &&
      kubernetes_stateful_set.onify-app.spec[0].template[0].spec[0].container[0].image == "example/citizen-app:root" &&
      kubernetes_service.onify-app.metadata[0].name == "app" &&
      kubernetes_service.onify-app.spec[0].port[0].port == 4000
    )
    error_message = "Citizen must deploy a single app Service and StatefulSet."
  }

  assert {
    condition = alltrue([
      for rule in kubernetes_ingress_v1.onify-app[0].spec[0].rule :
      length(rule.http[0].path) == 1 &&
      rule.http[0].path[0].path == "/" &&
      rule.http[0].path[0].backend[0].service[0].name == "app" &&
      rule.http[0].path[0].backend[0].service[0].port[0].number == 4000
    ])
    error_message = "The primary and custom hosts must route only / to the Citizen app."
  }

  assert {
    condition = tomap({
      for env in kubernetes_stateful_set.onify-app.spec[0].template[0].spec[0].container[0].env : env.name => env.value
    }) == tomap({ ONIFY_API_URL_INTERNAL = "http://api:8181" })
    error_message = "The root proxy must receive the Citizen API URL, even when a caller supplies a different one."
  }

  assert {
    condition = (
      kubernetes_service.onify-api.metadata[0].name == "api" &&
      kubernetes_stateful_set.onify-worker.metadata[0].name == "example-prod-worker" &&
      kubernetes_stateful_set.onify-worker.spec[0].template[0].spec[0].container[0].image == "example/api:stable" &&
      kubernetes_service.onify-functions.metadata[0].name == "functions" &&
      kubernetes_service.elasticsearch[0].metadata[0].name == "elasticsearch" &&
      kubernetes_config_map.onify-api.data.ONIFY_db_elasticsearch_host == "http://elasticsearch:9200" &&
      kubernetes_stateful_set.onify-api.spec[0].template[0].metadata[0].annotations["checksum/api-config"] == sha256(jsonencode(kubernetes_config_map.onify-api.data)) &&
      kubernetes_stateful_set.onify-worker.spec[0].template[0].metadata[0].annotations["checksum/api-config"] == sha256(jsonencode(kubernetes_config_map.onify-api.data)) &&
      alltrue([for rule in kubernetes_ingress_v1.onify-api[0].spec[0].rule : rule.http[0].path[0].backend[0].service[0].name == "api"]) &&
      alltrue([for rule in kubernetes_ingress_v1.onify-functions[0].spec[0].rule : rule.http[0].path[0].backend[0].service[0].name == "functions"])
    )
    error_message = "Services and their internal callers must use namespace-local names."
  }

  assert {
    condition     = keys(jsondecode(kubernetes_secret.docker-onify.data[".dockerconfigjson"]).auths) == ["eu.gcr.io"]
    error_message = "The image pull-secret must contain only GCR authentication."
  }
}
