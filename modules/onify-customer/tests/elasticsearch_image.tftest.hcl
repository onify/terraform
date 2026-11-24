mock_provider "kubernetes" {}
mock_provider "null" {}

variables {
  gcr_registry_keyfile = "tests/fixtures/keyfile.json"
  onify_hub_api_envs = {
    ONIFY_client_code     = "example"
    ONIFY_client_instance = "test"
  }
  elasticsearch_version = "7.16.1"
}

run "default_elasticsearch_image" {
  command = plan

  assert {
    condition = (
      kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].container[0].image == "docker.elastic.co/elasticsearch/elasticsearch:7.16.1" &&
      length(kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].image_pull_secrets) == 0
    )
    error_message = "The default Pod must retain its versioned Elastic image and existing pull configuration."
  }
}

run "custom_elasticsearch_image" {
  command = plan

  variables {
    elasticsearch_image_override = "example.invalid/elasticsearch@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition = (
      kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].container[0].image == var.elasticsearch_image_override &&
      one(kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].image_pull_secrets).name == "onify-regcred" &&
      kubernetes_stateful_set.elasticsearch[0].spec[0].update_strategy[0].rolling_update[0].partition == 1
    )
    error_message = "The custom image must use the existing registry secret and preserve rollout partition 1."
  }
}
