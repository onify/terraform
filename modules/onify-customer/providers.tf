terraform {
  required_version = "> 1.5, < 1.6"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "< 2.25.0"
    }
  }
}