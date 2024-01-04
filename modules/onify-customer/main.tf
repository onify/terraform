module "helix" {
  count      = var.helix ? 1 : 0
  source     = "./helix"
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]

  kubernetes_node_api_worker    = var.kubernetes_node_api_worker
  helix                         = var.helix
  ingress                       = var.ingress
  ghcr_registry_password        = var.ghcr_registry_password
  ghcr_registry_username        = var.ghcr_registry_username
  onify_hub_worker_tls              = var.onify_hub_worker_tls
  onify_hub_agent_tls               = var.onify_hub_agent_tls
  onify_hub_api_tls                 = var.onify_hub_api_tls
  onify_hub_app_tls             = var.onify_hub_app_tls
  custom_hostname               = var.custom_hostname
  elasticsearch_external        = var.elasticsearch_external
  tls                           = var.tls
  deployment_replicas           = var.deployment_replicas
  gcr_registry_keyfile          = var.gcr_registry_keyfile
  onify_hub_functions_image         = var.onify_hub_functions_image
  onify_helix_image             = var.onify_helix_image
  onify_hub_app_image               = var.onify_hub_app_image
  onify_hub_agent_image             = var.onify_hub_agent_image
  onify_hub_api_image               = var.onify_hub_api_image
  onify_hub_worker_image            = var.onify_hub_worker_image
  onify_hub_api_external            = var.onify_hub_api_external
  onify_hub_functions_external      = var.onify_hub_functions_external
  onify_hub_agent_external          = var.onify_hub_agent_external
  elasticsearch_address         = var.elasticsearch_address
  elasticsearch_heapsize        = var.elasticsearch_heapsize
  elasticsearch_disksize        = var.elasticsearch_disksize
  elasticsearch_memory_limit    = var.elasticsearch_memory_limit
  elasticsearch_memory_requests = var.elasticsearch_memory_requests
  elasticsearch_version         = var.elasticsearch_version
  onify_hub_api_memory_limit        = var.onify_hub_api_memory_limit
  onify_hub_api_cpu_limit           = var.onify_hub_api_cpu_limit
  onify_hub_api_memory_requests     = var.onify_hub_api_memory_requests
  onify_hub_api_cpu_requests        = var.onify_hub_api_cpu_requests
  onify_hub_agent_memory_limit      = var.onify_hub_agent_memory_limit
  onify_hub_agent_cpu_limit         = var.onify_hub_agent_cpu_limit
  onify_hub_agent_memory_requests   = var.onify_hub_agent_memory_requests
  onify_hub_worker_memory_limit     = var.onify_hub_worker_memory_limit
  onify_hub_worker_cpu_limit        = var.onify_hub_worker_cpu_limit
  onify_hub_worker_memory_requests  = var.onify_hub_worker_memory_requests
  onify_hub_worker_cpu_requests     = var.onify_hub_worker_cpu_requests
  onify_hub_app_memory_limit        = var.onify_hub_app_memory_limit
  onify_hub_app_cpu_limit           = var.onify_hub_app_cpu_limit
  onify_hub_app_memory_requests     = var.onify_hub_app_memory_requests
  onify_hub_app_cpu_requests        = var.onify_hub_app_cpu_requests
  external_dns_domain           = var.external_dns_domain
  gke                           = var.gke
  onify_agent_envs              = var.onify_agent_envs
  onify_hub_api_envs                = var.onify_hub_api_envs
  onify_hub_app_envs                = var.onify_hub_app_envs
  onify_app_helix_envs          = var.onify_app_helix_envs
  onify_functions_envs          = var.onify_functions_envs

}

module "hub" {
  count      = var.helix ? 0 : 1
  source     = "./hub"
  depends_on = [kubernetes_namespace.customer_namespace,kubernetes_secret.docker-onify]

  kubernetes_node_api_worker    = var.kubernetes_node_api_worker
  helix                         = var.helix
  ingress                       = var.ingress
  ghcr_registry_password        = var.ghcr_registry_password
  ghcr_registry_username        = var.ghcr_registry_username
  onify_hub_worker_tls              = var.onify_hub_worker_tls
  onify_hub_agent_tls               = var.onify_hub_agent_tls
  onify_hub_api_tls                 = var.onify_hub_api_tls
  onify_hub_app_tls                 = var.onify_hub_app_tls
  custom_hostname               = var.custom_hostname
  elasticsearch_external        = var.elasticsearch_external
  tls                           = var.tls
  deployment_replicas           = var.deployment_replicas
  gcr_registry_keyfile          = var.gcr_registry_keyfile
  onify_hub_functions_image         = var.onify_hub_functions_image
  onify_helix_image             = var.onify_helix_image
  onify_hub_app_image               = var.onify_hub_app_image
  onify_hub_agent_image             = var.onify_hub_agent_image
  onify_hub_api_image               = var.onify_hub_api_image
  onify_hub_worker_image            = var.onify_hub_worker_image
  onify_hub_api_external            = var.onify_hub_api_external
  onify_hub_functions_external      = var.onify_hub_functions_external
  onify_hub_agent_external          = var.onify_hub_agent_external
  elasticsearch_address         = var.elasticsearch_address
  elasticsearch_heapsize        = var.elasticsearch_heapsize
  elasticsearch_disksize        = var.elasticsearch_disksize
  elasticsearch_memory_limit    = var.elasticsearch_memory_limit
  elasticsearch_memory_requests = var.elasticsearch_memory_requests
  elasticsearch_version         = var.elasticsearch_version
  onify_hub_api_memory_limit        = var.onify_hub_api_memory_limit
  onify_hub_api_cpu_limit           = var.onify_hub_api_cpu_limit
  onify_hub_api_memory_requests     = var.onify_hub_api_memory_requests
  onify_hub_api_cpu_requests        = var.onify_hub_api_cpu_requests
  onify_hub_agent_memory_limit      = var.onify_hub_agent_memory_limit
  onify_hub_agent_cpu_limit         = var.onify_hub_agent_cpu_limit
  onify_hub_agent_memory_requests   = var.onify_hub_agent_memory_requests
  onify_hub_worker_memory_limit     = var.onify_hub_worker_memory_limit
  onify_hub_worker_cpu_limit        = var.onify_hub_worker_cpu_limit
  onify_hub_worker_memory_requests  = var.onify_hub_worker_memory_requests
  onify_hub_worker_cpu_requests     = var.onify_hub_worker_cpu_requests
  onify_hub_app_memory_limit        = var.onify_hub_app_memory_limit
  onify_hub_app_cpu_limit           = var.onify_hub_app_cpu_limit
  onify_hub_app_memory_requests     = var.onify_hub_app_memory_requests
  onify_hub_app_cpu_requests        = var.onify_hub_app_cpu_requests
  external_dns_domain           = var.external_dns_domain
  gke                           = var.gke
  onify_agent_envs              = var.onify_agent_envs
  onify_hub_api_envs                = var.onify_hub_api_envs
  onify_hub_app_envs                = var.onify_hub_app_envs
  onify_app_helix_envs          = var.onify_app_helix_envs
  onify_functions_envs          = var.onify_functions_envs
}