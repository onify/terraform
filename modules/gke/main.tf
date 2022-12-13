locals {
  cluster_endpoint                = google_container_cluster.primary.endpoint
  cluster_output_master_auth      = concat(google_container_cluster.primary.*.master_auth, [])
  cluster_master_auth_list_layer1 = local.cluster_output_master_auth
  cluster_master_auth_list_layer2 = local.cluster_master_auth_list_layer1[0]
  cluster_master_auth_map         = local.cluster_master_auth_list_layer2[0]
  cluster_ca_certificate          = local.cluster_master_auth_map["cluster_ca_certificate"]
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name = "${var.name}-gke"
  networking_mode = "VPC_NATIVE"
  location = "${var.gce_region}-a"
  remove_default_node_pool = false
  initial_node_count       = 1

  ip_allocation_policy {}
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  resource_labels = {
  	type = "dev"
  }
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name = "${google_container_cluster.primary.name}-primary-node-pool"
  location   = "${var.gce_region}-a"
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes
   autoscaling {
      max_node_count = var.gke_num_nodes
      min_node_count = 1
   }
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = "${var.gce_project_id}-gke"
    }

    machine_type = "n1-standard-1"
    tags         = ["gke-node", "${var.name}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
