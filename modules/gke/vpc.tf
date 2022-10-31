# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.name}-gke-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name}-gke-subnet"
  region        = var.gce_region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}
