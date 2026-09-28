module "citizen" {
  source = "../" # In a deployment root: //modules/onify-citizen

  gcr_registry_keyfile  = var.gcr_registry_keyfile
  onify_api_envs        = var.onify_api_envs
  onify_api_image       = var.onify_api_image
  onify_app_image       = var.onify_app_image
  onify_functions_image = var.onify_functions_image
  onify_gateway_image   = var.onify_gateway_image

  # When converting an existing installation, copy all existing
  # elasticsearch_* and gke values without changing them.
}

variable "gcr_registry_keyfile" { type = string }
variable "onify_api_envs" { type = map(string) }
variable "onify_api_image" { type = string }
variable "onify_app_image" { type = string }
variable "onify_functions_image" { type = string }
variable "onify_gateway_image" { type = string }
