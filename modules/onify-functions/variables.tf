variable "client_code" {
}

variable "client_instance" {
}

variable "name" {
  type = string
}

variable "image" {
  type = string
}
variable "port" {
  type = number
}

variable "envs" {
  type    = map(string)
  default = {
      "VERSION" = "1.0"
  }
}
variable "tls" {
  type = string
  default = "staging"
}

variable "public" {
  default = false
}

variable "external_dns_domain" {
  type = string
}
