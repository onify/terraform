output "gce_region" {
  value       = var.gce_region
  description = "GCloud Region"
}

output "gce_project_id" {
  value       = var.gce_project_id
  description = "GCloud Project ID"
}

output "endpoint" {
  sensitive   = true
  description = "Cluster endpoint"
  value       = local.cluster_endpoint
  depends_on = [
    /* Nominally, the endpoint is populated as soon as it is known to Terraform.
    * However, the cluster may not be in a usable state yet.  Therefore any
    * resources dependent on the cluster being up will fail to deploy.  With
    * this explicit dependency, dependent resources can wait for the cluster
    * to be up.

    * source: https://github.com/terraform-google-modules/terraform-google-kubernetes-engine
    */
    google_container_cluster.primary,
    google_container_node_pool.primary_nodes,
  ]
}

output "ca_certificate" {
  sensitive   = true
  description = "Cluster ca certificate (base64 encoded)"
  value       = local.cluster_ca_certificate
}