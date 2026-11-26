locals {
  namespace = "${var.onify_api_envs.ONIFY_client_code}-${var.onify_api_envs.ONIFY_client_instance}"
}

variable "onify_api_image" {
  type = string
}

variable "image_pull_policy" {
  description = "Kubernetes image pull policy for the Citizen API, app, worker and gateway. Defaults to Always. Set to IfNotPresent or Never to override."
  type        = string
  default     = "Always"
  nullable    = false

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image_pull_policy)
    error_message = "Use Always, IfNotPresent or Never."
  }
}

variable "onify_app_image" {
  type = string
}

variable "custom_hostname" {
  description = "Additional public hostnames for the cluster profile. On dev1, short labels and legacy names such as nacka.dev expand under both Onify domains."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([for host in var.custom_hostname : try(
      length(trimsuffix(host, ".")) <= 253 &&
      alltrue([for label in split(".", trimsuffix(host, ".")) : can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", label))]) &&
      (!endswith(host, ".") || length(split(".", host)) >= 3), false
    )])
    error_message = "Use lowercase DNS labels or exact domain names, without wildcards, schemes, ports or paths."
  }
}

variable "onify_worker_image" {
  type = string
}

variable "onify_gateway_image" {
  type = string
}

variable "onify_api_envs" {
  description = "API and worker settings. Client code and instance determine the namespace."
  type        = map(string)

  validation {
    condition     = alltrue([for key in ["ONIFY_client_code", "ONIFY_client_instance"] : try(trimspace(var.onify_api_envs[key]) != "", false)])
    error_message = "Set ONIFY_client_code and ONIFY_client_instance for this installation."
  }
}

variable "onify_app_envs" {
  type    = map(string)
  default = { ONIFY_API_URL_INTERNAL = "http://onify-citizen-api:8181" }
}

variable "onify_gateway_envs" {
  type    = map(string)
  default = {}
}

variable "runtime_secrets" {
  description = "Names of existing environment Secrets. The worker uses the API Secret."
  type = object({
    api     = optional(string)
    app     = optional(string)
    gateway = optional(string)
  })
  default  = {}
  nullable = false
}

variable "namespace_labels" {
  type    = map(string)
  default = {}
}

variable "elasticsearch_address" {
  description = "Existing Elasticsearch URL. Defaults to the Elasticsearch Service for the instance."
  type        = string
  default     = null
}

variable "worker_replicas" {
  type    = number
  default = 1
}

variable "gcr_registry_keyfile" {
  description = "Optional path to the Google registry service account key used to pull Citizen images."
  type        = string
  default     = null
}
