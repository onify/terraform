# Onify Citizen for Kubernetes

This module runs the Citizen API, app, worker and gateway on an existing Kubernetes cluster. It manages their namespace, internal Services and API ConfigMap. Public routing and gateway configuration are managed separately.

In the calling root, configure the Kubernetes provider and set the four image references and `onify_api_envs`. The API client code and instance determine the namespace. The API and worker use `http://<client>-<instance>-elasticsearch:9200` by default. Override `elasticsearch_address` to use another service. Workloads use `IfNotPresent` for images. Supply `gcr_registry_keyfile` to pull private images from `eu.gcr.io`. Set `worker_replicas` to scale background processing.

Use the three environment maps for workload settings. Protect Terraform state and saved plans when specifying credentials directly. API and worker share `onify_api_envs`. Use `runtime_secrets` to reference existing namespace Secrets by name for the API, app or gateway. Explicit environment entries take precedence. The gateway listens on port 8686.

When the calling module owns the instance namespace, set `create_namespace = false` and make the module depend on namespace provisioning. Existing installations keep namespace ownership by default.
