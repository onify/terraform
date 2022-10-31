variable "gce_project_id" {
  description = "google cloud project id"
}
variable "external-dns-domain" {
  default = "onify.io"
}
variable "gke" {
  default = false 
}