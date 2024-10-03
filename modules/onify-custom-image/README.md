This is a terraform module for using custom image with an ingress controller.

Example code below. Commented variables are optional and default value in parenthesis.


This module expects that a kubernetes namesspace with "client_code-client_instance" exists.


Default http host will be:
https://client_code-client_instance.external_dns_domain


```
module "onify-custom-image" {
  source = "github.com/onify/terraform//modules/onify-custom-image"

  name                    = "abou"
  client_code             = "oni"
  client_instance         = "dev"
  image                   = "nginx:latest"

  // port                  = 80
  // external_dns_domain   = "onify.net"
  // tls                   = "staging"
  // envs                  = {
  // "FOO" = "BAR"
  // }
  // custom_hostname        = ""

  // #IMAGE PULL SECRETS
  // ghcr_registry_password = ""
  // ghcr_registry_username = ""
  // gcr_registry_keyfile   = "keyfile.json"
}
```


