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

run "legacy_storage_supports_gateway_only_and_helix_only" {
  command = plan

  variables {
    gke                          = false
    elasticsearch_legacy_storage = true
    onify_hub_gateway_image      = "example/gateway:stable"
    onify_hub_functions_enabled  = false
    onify_hub_functions_external = true
    helix_only                   = true
  }

  assert {
    condition = (
      kubernetes_namespace.customer_namespace.metadata[0].name == "example-test" &&
      kubernetes_persistent_volume.local[0].metadata[0].name == "example-test-data" &&
      kubernetes_persistent_volume.local[0].spec[0].storage_class_name == "local" &&
      kubernetes_persistent_volume.local[0].spec[0].persistent_volume_reclaim_policy == "Retain" &&
      kubernetes_persistent_volume.local[0].spec[0].persistent_volume_source[0].host_path[0].path == "/usr/share/elasticsearch/data" &&
      length(kubernetes_persistent_volume_claim.elasticsearch_data) == 0 &&
      kubernetes_stateful_set.elasticsearch[0].metadata[0].name == "example-test-elasticsearch" &&
      kubernetes_stateful_set.elasticsearch[0].spec[0].service_name == "example-test-elasticsearch" &&
      one(kubernetes_stateful_set.elasticsearch[0].spec[0].volume_claim_template).metadata[0].name == "example-test-data" &&
      one(kubernetes_stateful_set.elasticsearch[0].spec[0].volume_claim_template).spec[0].storage_class_name == "local" &&
      length(kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].volume) == 0
    )
    error_message = "The legacy data PV, claim template and StatefulSet must keep their consolidate identities."
  }

  assert {
    condition = (
      length(kubernetes_stateful_set.onify-hub-functions) == 0 &&
      length(kubernetes_service.onify-hub-functions) == 0 &&
      length(kubernetes_service.onify-hub-functions-alias) == 0 &&
      length(kubernetes_ingress_v1.onify-hub-functions) == 0 &&
      length(kubernetes_stateful_set.onify-hub-gateway) == 1 &&
      kubernetes_service_v1.onify-hub-gateway-alias[0].metadata[0].name == "hub-gateway" &&
      module.helix[0].helix_only
    )
    error_message = "Legacy storage must support Gateway without any Functions resources and with Helix-only enabled."
  }
}

run "legacy_gke_storage_keeps_the_consolidate_pv" {
  command = plan

  variables {
    gke                          = true
    elasticsearch_legacy_storage = true
  }

  assert {
    condition = (
      kubernetes_persistent_volume.local[0].metadata[0].name == "example-test-data" &&
      kubernetes_persistent_volume.local[0].spec[0].storage_class_name == "local" &&
      length(kubernetes_persistent_volume_claim.elasticsearch_data) == 0 &&
      one(kubernetes_stateful_set.elasticsearch[0].spec[0].volume_claim_template).metadata[0].name == "example-test-data" &&
      one(kubernetes_stateful_set.elasticsearch[0].spec[0].volume_claim_template).spec[0].storage_class_name == ""
    )
    error_message = "The GKE compatibility path must retain the legacy PV and dynamically provisioned claim template."
  }
}

run "managed_gke_storage_and_functions_remain_the_defaults" {
  command = plan

  variables {
    gke = true
  }

  assert {
    condition = (
      length(kubernetes_persistent_volume.local) == 0 &&
      kubernetes_persistent_volume_claim.elasticsearch_data[0].metadata[0].name == "example-test-data-example-test-elasticsearch-0" &&
      length(kubernetes_stateful_set.elasticsearch[0].spec[0].volume_claim_template) == 0 &&
      one(kubernetes_stateful_set.elasticsearch[0].spec[0].template[0].spec[0].volume).persistent_volume_claim[0].claim_name == "example-test-data-example-test-elasticsearch-0"
    )
    error_message = "Existing main installations must retain their standalone data PVC by default."
  }

  assert {
    condition = (
      kubernetes_stateful_set.onify-hub-functions[0].metadata[0].name == "example-test-hub-functions" &&
      kubernetes_service.onify-hub-functions[0].metadata[0].name == "example-test-hub-functions" &&
      kubernetes_service.onify-hub-functions-alias[0].metadata[0].name == "hub-functions"
    )
    error_message = "Functions must keep the existing workload and Service names by default."
  }
}
