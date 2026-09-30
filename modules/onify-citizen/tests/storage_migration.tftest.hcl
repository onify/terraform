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
    ONIFY_client_instance = "prod"
    ONIFY_db_indexPrefix  = "existing-index"
  }
}

run "gke_keeps_customer_storage_names" {
  command = plan

  assert {
    condition = (
      kubernetes_namespace.customer_namespace.metadata[0].name == "example-prod" &&
      kubernetes_stateful_set.elasticsearch[0].metadata[0].name == "example-prod-elasticsearch" &&
      kubernetes_stateful_set.elasticsearch[0].spec[0].service_name == "example-prod-elasticsearch" &&
      kubernetes_service.elasticsearch[0].metadata[0].name == "onify-citizen-elasticsearch" &&
      kubernetes_persistent_volume_claim.elasticsearch_data[0].metadata[0].name == "example-prod-data-example-prod-elasticsearch-0" &&
      kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].volume[0].persistent_volume_claim[0].claim_name == kubernetes_persistent_volume_claim.elasticsearch_data[0].metadata[0].name &&
      length(kubernetes_persistent_volume.local) == 0
    )
    error_message = "Citizen must keep the existing namespace, Elasticsearch StatefulSet and data claim."
  }

  assert {
    condition     = kubernetes_deployment_v1.onify-gateway.metadata[0].name == "example-prod-gateway"
    error_message = "Gateway must be deployed alongside the Citizen workloads."
  }
}

run "local_backup_keeps_customer_volume_names" {
  command = plan

  variables {
    gke                          = false
    elasticsearch_backup_enabled = true
    elasticsearch_external       = true
  }

  assert {
    condition = (
      kubernetes_persistent_volume.local[0].metadata[0].name == "example-prod-data" &&
      kubernetes_persistent_volume.elasticsearch_backup[0].metadata[0].name == "example-prod-backup" &&
      kubernetes_persistent_volume_claim.elasticsearch_backup[0].metadata[0].name == "example-prod-backup-example-prod-elasticsearch-0" &&
      kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].volume[1].persistent_volume_claim[0].claim_name == kubernetes_persistent_volume_claim.elasticsearch_backup[0].metadata[0].name
    )
    error_message = "Local data and backup volumes must retain their Customer names."
  }

  assert {
    condition     = kubernetes_ingress_v1.onify-elasticsearch[0].spec[0].rule[0].http[0].path[0].backend[0].service[0].name == kubernetes_service.elasticsearch[0].metadata[0].name
    error_message = "The Elasticsearch Ingress must route to the Citizen Service."
  }
}

run "external_elasticsearch_keeps_its_address" {
  command = plan

  variables {
    elasticsearch_address = "https://search.example:9200"
  }

  assert {
    condition = (
      length(kubernetes_service.elasticsearch) == 0 &&
      kubernetes_config_map.onify-api.data.ONIFY_db_elasticsearch_host == "https://search.example:9200"
    )
    error_message = "An external Elasticsearch address must not create an internal Service."
  }
}
