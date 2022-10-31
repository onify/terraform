variable "name" {}
variable "gce_project_id" {}

resource "google_storage_bucket" "gcs" {
  name          = var.name
  project	      = var.gce_project_id
  location      = "EU"
  force_destroy = false
}

output "gcs_name" {
  value       = google_storage_bucket.gcs.name
  description = "The name of the google storage bucket name"
}
