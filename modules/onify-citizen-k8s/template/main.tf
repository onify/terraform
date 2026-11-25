terraform {
  backend "local" {}
  required_version = ">= 1.6, < 2"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.24.0"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand("~/.kube/dev1.config")
  config_context = "hostup-development"
  host           = "https://dev1.onify.io:16443"
}

variable "ONIFY_initialLicense" { sensitive = true }
variable "ONIFY_adminUser_password" { sensitive = true }
variable "ONIFY_apiTokens_app_secret" { sensitive = true }
variable "ONIFY_client_secret" { sensitive = true }

module "citizen" {
  source = "github.com/onify/terraform//modules/onify-citizen-k8s"

  environment_profile  = "onify-citizen-dev1"
  custom_hostname      = [] # e.g. ["acme-portal.dev", "citizen.example.se"]
  gcr_registry_keyfile = "${path.module}/keyfile.json"
  onify_api_image      = "eu.gcr.io/onify-images/hub/api:dev"
  onify_worker_image   = "eu.gcr.io/onify-images/hub/api:dev"
  onify_app_image      = "eu.gcr.io/onify-images/citizen/app-root:dev"
  onify_gateway_image  = "eu.gcr.io/onify-images/halo-gateway:main"

  onify_api_envs = {
    DEBUG                              = "bpmn-engine:error*"
    ENV_PREFIX                         = "ONIFY_"
    INTERPRET_CHAR_AS_DOT              = "_"
    NODE_ENV                           = "development"
    ONIFY_adminUser_email              = "admin@onify.local"
    ONIFY_adminUser_username           = "admin"
    ONIFY_autoinstall                  = "true"
    ONIFY_client_code                  = "acme"
    ONIFY_client_instance              = "dev"
    ONIFY_client_multiTenant           = "true"
    ONIFY_db_indexPrefix               = "onify"
    ONIFY_logging_elasticFlushInterval = "500"
    ONIFY_logging_log                  = "stdout,elastic"
    ONIFY_resources_baseDir            = "/usr/share/onify/resources"
    ONIFY_resources_tempDir            = "/usr/share/onify/temp_resources"
    ONIFY_worker_cleanupInterval       = "300"
    ONIFY_initialLicense               = var.ONIFY_initialLicense
    ONIFY_adminUser_password           = var.ONIFY_adminUser_password
    ONIFY_apiTokens_app_secret         = var.ONIFY_apiTokens_app_secret
    ONIFY_client_secret                = var.ONIFY_client_secret
  }

  onify_app_envs = {
    ONIFY_API_URL_INTERNAL = "http://onify-citizen-api:8181"
  }

  onify_gateway_envs = {
    NODE_ENV                                         = "development"
    GATEWAY_TENANCY                                  = "single"
    GATEWAY_FAKE_MODE                                = "true"
    GATEWAY_AUTH                                     = "none"
    GATEWAY_INDEXING_METADATA                        = "true"
    GATEWAY_INTEGRATION_SSBTGO_ORGANIZATIONS_ENABLED = "true"
    GATEWAY_INTEGRATION_BYGGR_CASES_ENABLED          = "true"
  }
}

output "url" {
  value = module.citizen.url
}
