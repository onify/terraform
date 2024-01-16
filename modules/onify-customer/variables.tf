locals {
  client_code    = var.onify_hub_api_envs.ONIFY_client_code
  onify_instance = var.onify_hub_api_envs.ONIFY_client_instance
}
variable "kubernetes_node_api_worker" {
  default = null
}
variable "hub_app_path" {
  default = "/"
  type    = string
}
variable "helix_path" {
  default = "/helix"
  type    = string
}
variable "helix" {
  default = true
}
variable "ingress" {
  default = true
}
variable "ghcr_registry_password" {
  default = "1234"
}
variable "ghcr_registry_username" {
  default = "onify"
}
variable "onify_hub_worker_tls" {
  type    = string
  default = null
}
variable "onify_hub_agent_tls" {
  type    = string
  default = null
}
variable "onify_hub_api_tls" {
  type    = string
  default = null
}
variable "onify_hub_functions_tls" {
  type    = string
  default = null
}
variable "onify_hub_app_tls" {
  type    = string
  default = null
}
variable "custom_hostname" {
  type    = list(string)
  default = null
}
variable "elasticsearch_external" {
  default = false
}
variable "tls" {
  default = "prod"
}
variable "deployment_replicas" {
  default = 1
}
variable "gcr_registry_keyfile" {
  default = null
}
variable "onify_hub_functions_image" {
  default = "eu.gcr.io/onify-images/hub/functions:latest"
}
variable "onify_helix_image" {
  default = "ghcr.io/onify/helix-app-lab:latest"
}
variable "onify_hub_app_image" {
  default = "eu.gcr.io/onify-images/hub/app:latest"
}
variable "onify_hub_agent_image" {
  default = "eu.gcr.io/onify-images/hub/agent-server:latest"
}
variable "onify_hub_api_image" {
  default = "eu.gcr.io/onify-images/hub/api:latest"
}
variable "onify_hub_worker_image" {
  default = "eu.gcr.io/onify-images/hub/api:latest"
}
variable "onify_hub_api_external" {
  default = true
}
variable "onify_hub_functions_external" {
  default = true
}
variable "onify_hub_agent_external" {
  default = true
}
variable "elasticsearch_address" {
  type    = string
  default = null
}
variable "elasticsearch_heapsize" {
  type    = string
  default = null
}
variable "elasticsearch_disksize" {
  default = "10Gi"
}
variable "elasticsearch_memory_limit" {
  default = "1Gi"
}
variable "elasticsearch_memory_requests" {
  default = "1Gi"
}
variable "elasticsearch_version" {
  default = "7.16.1"
}
variable "onify_hub_api_memory_limit" {
  default = "100Mi"
}
variable "onify_hub_api_cpu_limit" {
  default = "100m"
}
variable "onify_hub_api_memory_requests" {
  default = "100Mi"
}
variable "onify_hub_api_cpu_requests" {
  default = "100m"
}
variable "onify_hub_agent_memory_limit" {
  default = "100Mi"
}
variable "onify_hub_agent_cpu_limit" {
  default = "100m"
}
variable "onify_hub_agent_memory_requests" {
  default = "100Mi"
}
variable "onify_hub_agent_cpu_requests" {
  default = "100m"
}
variable "onify_hub_worker_memory_limit" {
  default = "100Mi"
}
variable "onify_hub_worker_cpu_limit" {
  default = "100m"
}
variable "onify_hub_worker_memory_requests" {
  default = "100Mi"
}
variable "onify_hub_worker_cpu_requests" {
  default = "100m"
}
variable "onify_hub_app_memory_limit" {
  default = "100Mi"
}
variable "onify_hub_app_cpu_limit" {
  default = "100m"
}
variable "onify_hub_app_memory_requests" {
  default = "100Mi"
}
variable "onify_hub_app_cpu_requests" {
  default = "100m"
}
variable "external_dns_domain" {
  default = "onify.io"
}
variable "gke" {
  default = true
}

variable "onify_hub_agent_envs" {
  type = map(string)
  default = {
    "log_level"   = "2"
    "log_type"    = "1"
    "hub_version" = "v2"
  }
}

variable "onify_hub_api_envs" {
  type = map(string)
  default = {
    NODE_ENV                   = "production"
    ENV_PREFIX                 = "ONIFY_"
    INTERPRET_CHAR_AS_DOT      = "_"
    ONIFY_db_indexPrefix       = "onify" # indices will be prefixed with this string
    ONIFY_adminUser_username   = "admin"
    ONIFY_adminUser_email      = "admin@onify.local"
    ONIFY_resources_baseDir    = "/usr/share/onify/resources"
    ONIFY_resources_tempDir    = "/usr/share/onify/temp_resources"
    ONIFY_autoinstall          = true
    ONIFY_client_code          = "xxxx"
    ONIFY_client_instance      = "xxxx"
    ONIFY_initialLicense       = "xxxx"
    ONIFY_adminUser_password   = ""
    ONIFY_apiTokens_app_secret = ""
    ONIFY_client_secret        = ""
  }
}

variable "onify_hub_app_envs" {
  type = map(string)
  default = {
    NODE_ENV                    = "production"
    ENV_PREFIX                  = "ONIFY_"
    INTERPRET_CHAR_AS_DOT       = "_"
    ONIFY_api_externalUrl       = "/api/v2"
    ONIFY_disableAdminEndpoints = true
    ONIFY_api_admintoken        = "xx"
  }
}
variable "onify_app_helix_envs" {
  type = map(string)
  default = {
  }
}
variable "onify_hub_functions_envs" {
  type = map(string)
  default = {
    NODE_ENV = "production"
  }
}
