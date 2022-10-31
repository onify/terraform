locals {
    name = "onify-${var.onify_api_envs.ONIFY_client_code}-${var.onify_api_envs.ONIFY_client_instance}"
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
variable "onify-app_version" {
    default = "latest"
}
variable "elasticsearch_heapsize" {
    type = string
    default = null
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
    default = "250Mi"
}
variable "onify-api_cpu_limit" {
    default = "200m"
}
variable "onify-api_memory_requests" {
    default = "250Mi"
}
variable "onify-api_cpu_requests" {
    default = "200m"
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
    default = "250Mi"
}
variable "onify-worker_cpu_limit" {
    default = "200m"
}
variable "onify-worker_memory_requests" {
    default = "250Mi"
}
variable "onify-worker_cpu_requests" {
    default = "200m"
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

variable "onify_agent_envs" {
  type    = map(string)
  default = {
      "log_level" = "2"
      "log_type" = "1"
      "hub_version" = "v2"
  }
}
variable "onify_default_envs" {
    type = map(string)
    default = {
        NODE_ENV                    = "production"
        ENV_PREFIX                  = "ONIFY_"
        INTERPRET_CHAR_AS_DOT       = "_"
  }
}
variable "onify_api_worker_defaults" {
    type = map(string)
    default = {
        ONIFY_db_indexPrefix        = "onify" # indices will be prefixed with this string
        ONIFY_adminUser_username    = "admin"
        ONIFY_adminUser_email       = "admin@onify.local"
        ONIFY_resources_baseDir     = "/usr/share/onify/resources"
        ONIFY_resources_tempDir     = "/usr/share/onify/temp_resources"
        ONIFY_autoinstall           = "true"
  }
}
variable "onify_api_envs" {
    type = map(string)
    default = {
        ONIFY_client_code           = "xxxx"
        ONIFY_client_instance       = "xxxx"
        ONIFY_initialLicense        = "xxxx"
        ONIFY_adminUser_password    = ""
        ONIFY_apiTokens_app_secret  = ""
        ONIFY_client_secret         = ""
        ONIFY_db_elasticsearch_host   = "http://elasticsearch:9200"
        ONIFY_websockets_agent_url    = "ws://onify-agent:8080/hub"
        #TZ                           = Europe/Stockholm
        #DEBUG                        = bpmn*  # For debuging BPMN processes
        #ONIFY_db_alwaysRefresh       = "true" # For testing purposes
        #ONIFY_logging_log            = stdout,elastic
        #ONIFY_logging_logLevel       = "debug" # For testing purposes
        #ONIFY_logging_elasticFlushInterval = "1000" # For testing purposes  
  }
}
variable "onify_app_envs" {
    type = map(string)
    default = {
    	ONIFY_api_externalUrl       = "/api/v2"
   	    ONIFY_disableAdminEndpoints = false
    	ONIFY_api_admintoken        = "xx"
        ONIFY_api_internalUrl       = "http://onify-api:8181/api/v2"
  }
}
variable "onify_worker_envs" {
    type = map(string)
    default = {
    ONIFY_worker_cleanupInterval = 30
  }
}
