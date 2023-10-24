locals {
    client_code = var.onify_api_envs.ONIFY_client_code
    onify_instance = var.onify_api_envs.ONIFY_client_instance
}
variable "helix" {
  default = false
  type = bool
}
variable "custom_hostname" {
    type = list(string)
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
}

variable "onify-agent_version" {
    default = "latest"
}
variable "onify-api_version" {
    default = "latest"
}
variable "onify-worker_version" {
    default = "latest"
}
variable "onify-helix_image" {
    default = "latest"
}
variable "onify-app_version" {
    default = "latest"
}
variable "onify-api_external" {
    default = true
}
variable "onify-functions_external" {
    default = true
}
variable "onify-agent_external" {
    default = true
}
variable "elasticsearch_address" {
    type = string
    default = null
}
variable "elasticsearch_heapsize" {
    type = string
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
variable "onify-api_memory_limit" {
    default = "100Mi"
}
variable "onify-api_cpu_limit" {
    default = "100m"
}
variable "onify-api_memory_requests" {
    default = "100Mi"
}
variable "onify-api_cpu_requests" {
    default = "100m"
}
variable "onify-agent_memory_limit" {
    default = "100Mi"
}
variable "onify-agent_cpu_limit" {
    default = "100m"
}
variable "onify-agent_memory_requests" {
    default = "100Mi"
}
variable "onify-agent_cpu_requests" {
    default = "100m"
}
variable "onify-worker_memory_limit" {
    default = "100Mi"
}
variable "onify-worker_cpu_limit" {
    default = "100m"
}
variable "onify-worker_memory_requests" {
    default = "100Mi"
}
variable "onify-worker_cpu_requests" {
    default = "100m"
}
variable "onify-app_memory_limit" {
    default = "100Mi"
}
variable "onify-app_cpu_limit" {
    default = "100m"
}
variable "onify-app_memory_requests" {
    default = "100Mi"
}
variable "onify-app_cpu_requests" {
    default = "100m"
}
variable "ssl_staging" {
    default = true
}
variable "external-dns-domain" {
  default = "onify.io"
}
variable "gke" {
  default = true
}

variable "onify_agent_envs" {
  type    = map(string)
  default = {
      "log_level" = "2"
      "log_type" = "1"
      "hub_version" = "v2"
  }
}

variable "onify_api_envs" {
    type = map(string)
    default = {
        NODE_ENV                    = "production"
        ENV_PREFIX                  = "ONIFY_"
        INTERPRET_CHAR_AS_DOT       = "_"
        ONIFY_db_indexPrefix        = "onify" # indices will be prefixed with this string
        ONIFY_adminUser_username    = "admin"
        ONIFY_adminUser_email       = "admin@onify.local"
        ONIFY_resources_baseDir     = "/usr/share/onify/resources"
        ONIFY_resources_tempDir     = "/usr/share/onify/temp_resources"
        ONIFY_autoinstall   = true
        ONIFY_client_code           = "xxxx"
        ONIFY_client_instance       = "xxxx"
        ONIFY_initialLicense        = "xxxx"
        ONIFY_adminUser_password    = ""
        ONIFY_apiTokens_app_secret  = ""
        ONIFY_client_secret     = ""
  }
}

variable "onify_app_envs" {
    type = map(string)
    default = {
    NODE_ENV              = "production"
    ENV_PREFIX            = "ONIFY_"
    INTERPRET_CHAR_AS_DOT = "_"
    ONIFY_api_externalUrl = "/api/v2"
    ONIFY_disableAdminEndpoints = true
    ONIFY_api_admintoken = "xx"
  }
}
variable "onify_app_helix_envs" {
    type = map(string)
    default = {
  }
}
variable "onify_functions_envs" {
    type = map(string)
    default = {
    NODE_ENV              = "production"
  }
}
