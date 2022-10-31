
variable "name" {}

variable "gce_project_id" {
  description = "google cloud project id"
}

variable "gce_region" {
  description = "google cloud region"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}