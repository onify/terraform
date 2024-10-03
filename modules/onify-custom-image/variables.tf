variable "client_code" {
  type = string
}

variable "client_instance" {
  type = string
}

variable "name" {
  type = string
}

variable "image" {
  type = string
}

variable "envs" {
  type = map(string)
  default = {
    "FOO" = "BAR"
  }
}
variable "tls" {
  type    = string
  default = "staging"
}

variable "external_dns_domain" {
  type    = string
  default = "onify.net"
}

variable "port" {
  type    = number
  default = 80
}
variable "pod_count" {
  type    = number
  default = 1
}
variable "ghcr_registry_password" {
  default = "1234"
}
variable "ghcr_registry_username" {
  default = "onify"
}
variable "custom_hostname" {
  type    = list(string)
  default = null
}
variable "gcr_registry_keyfile" {
  default = "keyfile.json"
}
variable "onify_custom_image_tls" {
  type    = string
  default = null
}
