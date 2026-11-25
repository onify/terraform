# Onify Citizen for Kubernetes

This module runs the Citizen API, app, worker and gateway on an existing Kubernetes cluster. It manages their namespace, internal Services and API ConfigMap. An optional cluster profile supplies public routing, storage and network policies.

In the calling root, configure the Kubernetes provider and set the four image references and `onify_api_envs`. The API client code and instance determine the namespace. The API and worker use `http://<client>-<instance>-elasticsearch:9200` by default. Override `elasticsearch_address` to use another service. Workloads use `IfNotPresent` for images. Supply `gcr_registry_keyfile` to pull private images from `eu.gcr.io`. Set `worker_replicas` to scale background processing.

Use the three environment maps for workload settings. Protect Terraform state and saved plans when specifying credentials directly. API and worker share `onify_api_envs`. Use `runtime_secrets` to reference existing namespace Secrets by name for the API, app or gateway. Explicit environment entries take precedence. The gateway listens on port 8686.

## Cluster-managed environments

Set `environment_profile` to the name of a platform-owned ConfigMap in `kube-system`. Its `profile.json` data entry identifies the cluster and describes its existing wildcard DNS domain, storage provisioner, Gateway API ListenerSet support and cert-manager HTTP-01 account. The module reads the profile to provision the namespace's Elasticsearch instance and PVC, network policies, exact HTTP/HTTPS listeners, routes and certificate. The `url` output is the public Citizen endpoint.

The profile fields are `cluster_uid` (the UID of the kube-system namespace), `domain`, `gateway_namespace`, `gateway_name`, `gateway_daemonset`, `acme_account_secret`, `storage_class`, `elasticsearch_image` (single-node Elasticsearch 7) and `additional_https_exclusions` (IPv4 CIDRs). Optional `api_envs` and `gateway_envs` supply shared nonsecret defaults. The profile requires CoreDNS, an NGINX Gateway allowing same-namespace ListenerSets, cert-manager's Gateway solver and a wildcard DNS record pointing to that Gateway. Each namespace receives a dedicated 10 GiB claim.

In profile mode, pass the four bootstrap credentials through `onify_api_envs` or supply the existing `runtime_secrets.api`. Inline bootstrap credentials go into an immutable Kubernetes Secret shared by API and worker. Terraform state and saved plans contain those values. Omitting the profile keeps the existing application-only deployment behavior.

### Public hostnames on dev1

```hcl
# Inside the Citizen module call
environment_profile = "onify-citizen-dev1"
custom_hostname     = ["nacka.dev", "norrtalje.dev", "portal.example.se"]
```

For client `sok` and instance `dev`, the profile automatically serves `sok-dev.dev1.onify.io` and `sok-dev.onify.net`. The optional list accepts the following forms.

| Input on dev1 | Public hostnames |
| --- | --- |
| `nacka.dev` (historical Sokigo format) | `nacka.dev1.onify.io` and `nacka.dev.onify.net` |
| `portal` | `portal.dev1.onify.io` and `portal.onify.net` |
| `portal.example.se` | `portal.example.se` |

A final dot always denotes an exact domain, e.g. `portal.dev.`. Outside dev1, a short label expands under the profile's domain and dotted names are used as given. Duplicate names share one route. Each hostname redirects HTTP to HTTPS and has its own certificate. The Gateway sends `/` to `onify-citizen-app:4000`. Use the Citizen root-proxy image so the app forwards `/api/v2/` to `onify-citizen-api:8181` with the tenant host and session. In multi-tenant installations, configure the hostname on the corresponding Citizen tenant.

The existing dev1 wildcard DNS records cover the two Onify domains. Point independently managed domains at the same Gateway before applying so cert-manager can complete HTTP-01 validation. Hosts already served by another Gateway listener or ListenerSet require a coordinated handover from their current owner.

`terraform destroy` removes the instance's routes, listeners, Certificate resources and namespace. Deleting the namespace also deletes its Elasticsearch claim and any resources managed there outside this module. In the shared Gateway namespace, cert-manager retains generated TLS Secrets by default. [cert-manager cleanup behavior](https://cert-manager.io/docs/usage/certificate/#cleaning-up-secrets-when-certificates-are-deleted)
