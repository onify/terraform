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

resource "google_compute_address" "gke_nat_ip" {
  count  = var.fixed_outside_ip ? 1 : 0
  name   = "${var.name}-gke-nat-ip"
  region = var.gce_region
}

resource "google_compute_router" "nat_router" {
  count  = var.fixed_outside_ip ? 1 : 0
  name    = "${var.name}-nat-router"
  network = google_compute_network.vpc.id
  region  = var.gce_region
}

resource "google_compute_router_nat" "nat_config" {
  count  = var.fixed_outside_ip ? 1 : 0
  name                               = "${var.name}-nat-config"
  router                             = google_compute_router.nat_router[count.index].name
  region                             = var.gce_region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.gke_nat_ip[count.index].id]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "allow_egress" {
  name    = "allow-egress-from-gke"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.10.0.0/24"]
}
