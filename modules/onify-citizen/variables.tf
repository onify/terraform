locals {
  client_code    = var.onify_api_envs.ONIFY_client_code
  onify_instance = var.onify_api_envs.ONIFY_client_instance
}
variable "kubernetes_node_api_worker" {
  default = null
}
variable "ingress" {
  default = true
}
variable "onify_api_tls" {
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
variable "elasticsearch_backup_enabled" {
  default = false
}
variable "elasticsearch_backup_schedule" {
  default = "0 30 1 * * ?"
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
variable "service_name_prefix" {
  description = "Prefix for Kubernetes Service names, including the trailing hyphen."
  type        = string
  default     = "onify-halo-"
  nullable    = false

  validation {
    condition     = length(var.service_name_prefix) <= 50 && can(regex("^[a-z][a-z0-9-]*-$", var.service_name_prefix))
    error_message = "service_name_prefix must be a lowercase Kubernetes name prefix ending in a hyphen, up to 50 characters."
  }
}
variable "onify_gateway_image" {
  description = "Gateway image."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.onify_gateway_image) != ""
    error_message = "onify_gateway_image must be a non-empty image reference."
  }
}
variable "onify_gateway_envs" {
  description = "Environment variables for Gateway. PORT is fixed to 8686."
  type        = map(string)
  default = {
    NODE_ENV = "production"
    PORT     = "8686"
  }
  nullable = false
}
variable "onify_api_image" {
  type     = string
  nullable = false
}
variable "onify_worker_image" {
  description = "Worker image. Defaults to the API image, started with the worker argument."
  type        = string
  default     = null
}
variable "onify_api_external" {
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
  default = null
}
variable "elasticsearch_memory_requests" {
  default = null
}
variable "elasticsearch_cpu_limit" {
  default = null
}
variable "elasticsearch_cpu_requests" {
  default = null
}
variable "elasticsearch_version" {
  default = "7.17.29"
}
variable "elasticsearch_xpack_security_enabled" {
  type    = bool
  default = false
}
variable "onify_api_memory_limit" {
  default = null
}
variable "onify_api_cpu_limit" {
  default = null
}
variable "onify_api_memory_requests" {
  default = null
}
variable "onify_api_cpu_requests" {
  default = null
}
variable "onify_worker_memory_limit" {
  default = null
}
variable "onify_worker_cpu_limit" {
  default = null
}
variable "onify_worker_memory_requests" {
  default = null
}
variable "onify_worker_cpu_requests" {
  default = null
}
variable "external_dns_domain" {
  default = "onify.io"
}
variable "gke" {
  default = true
}


variable "onify_api_envs" {
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

variable "onify_app_image" {
  description = "Citizen app image built for root-path operation."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.onify_app_image) != ""
    error_message = "onify_app_image must be a non-empty image reference."
  }
}

variable "onify_app_envs" {
  type    = map(string)
  default = {}
}

variable "onify_app_tls" {
  type    = string
  default = null
}

variable "onify_app_memory_limit" {
  default = null
}
variable "onify_app_cpu_limit" {
  default = null
}
variable "onify_app_memory_requests" {
  default = null
}
variable "onify_app_cpu_requests" {
  default = null
}
