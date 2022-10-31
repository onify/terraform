variable "name" {}
variable "machine_type" {
    default = "e2-medium"
}
variable "gce_project_id" {}
variable "gce_region" {}
variable "gce_zone" {}
variable "microk8sChannel" {
    default = "1.25/stable"
}

variable "gcp_dns_zone" {
    default = "onify"
}

variable "domain" {}
variable "os_image" {
    default = "ubuntu-os-cloud/ubuntu-2004-lts"
}
  variable "ssh_keys" {
  type = list(object({
    publickey = string
    user = string
  }))
  description = "list of public ssh keys that have access to the VM"
  default = [
      {
        user = "ubuntu"
        publickey = "ssh-ed25519 KEY description"
      }
  ]
}
variable "disk_size" {
    default = null
}
variable "disk_type" {
    type    = string
    default = null
}