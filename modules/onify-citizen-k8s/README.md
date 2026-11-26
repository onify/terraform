# Onify Citizen for Kubernetes

This module runs the Citizen API, app, worker and gateway on an existing Kubernetes cluster. It manages their namespace, internal Services and API ConfigMap. An optional cluster profile supplies public routing, storage and network policies.

For an installation already running on GKE, start with [Migrate an existing GKE instance to dev1](#migrate-an-existing-gke-instance-to-dev1).

## Deploy a new instance on dev1

The [standalone Terraform template](template/main.tf) selects the dev1 cluster profile and uses the Citizen root-proxy app image. You need Terraform 1.6 or later in the 1.x series, access to the dev1 VPN and a registry reader key for the private images. The template defaults to the `hostup-development` context in `~/.kube/dev1.config`. To create a kubeconfig from a token or a client certificate and use it with Terraform, see [Connect to a Kubernetes cluster](KUBECONFIG.md).

1. From the repository root, copy the template into a new directory dedicated to this instance. Keep that directory and its Terraform state for future updates and teardown. For an instance already managed on dev1, use its existing dev1 state.

   ```sh
   umask 077
   mkdir ../acme-dev-infra
   cp -R modules/onify-citizen-k8s/template/. ../acme-dev-infra/
   cd ../acme-dev-infra
   cp terraform.tfvars.example terraform.tfvars
   ```

2. In `main.tf`, set `ONIFY_client_code` and `ONIFY_client_instance` under `onify_api_envs`. Choose an unused combination. For example, `acme` and `dev` generate `acme-dev.dev1.onify.io` and `acme-dev.onify.net`. Add any aliases to `custom_hostname` in the same module call. Point customer-owned domains at the dev1 Gateway before applying. The API, app and gateway settings are grouped in this file as in `sok-dev-infra`. [Hostname formats](#public-hostnames-on-dev1)

3. Place the registry reader key in `keyfile.json` next to `main.tf`. Fill in the four private API values in `terraform.tfvars` from your secret manager. The template's `.gitignore` covers both files, local state and saved plans. Back up the state privately. [Example variables file](template/terraform.tfvars.example)

4. Initialize and review the plan. For a new installation, expect only creates. Check the namespace and hostnames before applying the saved plan.

   ```sh
   terraform init
   terraform validate
   terraform plan -out=citizen.tfplan
   terraform apply citizen.tfplan
   ```

5. Check the app and API. Both requests should return HTTP 200. Repeat with the second standard hostname and any configured aliases.

   ```sh
   url=$(terraform output -raw url)
   curl -fsS -o /dev/null -w '%{http_code}\n' "$url/"
   curl -fsS -o /dev/null -w '%{http_code}\n' "$url/api/v2/public/settings"
   ```

## Migrate an existing GKE instance to dev1

Keep the GKE deployment root, provider and Terraform state bound to GKE. Give dev1 its own root and state. Changing the module source or pointing the GKE state at dev1 cannot transfer Elasticsearch data. The older [Customer-to-Citizen conversion](../onify-citizen/MIGRATION.md) keeps the database volume on the **same cluster**. Either source module can migrate directly to dev1.

### Map the source configuration

Start with the running image versions, environment settings and secrets for the instance. Preserve `ONIFY_client_code`, `ONIFY_client_instance`, `ONIFY_db_indexPrefix` and the application's signing and encryption keys. Use the [template](template/main.tf) for the target module layout. Its development image tags, gateway authentication and integration switches are examples; retain the settings required by the deployed application.

| Target input | GKE `onify-citizen` | GKE `onify-customer` |
| --- | --- | --- |
| `onify_api_envs` | Start from `onify_api_envs`. | Start from `onify_hub_api_envs`. |
| `onify_api_image`, `onify_worker_image` | Keep the running API and worker versions. If the worker inherited the API image, set that image explicitly. | Map `onify_hub_api_image` and `onify_hub_worker_image`. |
| `onify_app_image`, `onify_app_envs` | Use the Citizen root-proxy image and the instance's app settings. | Review `onify_helix_image` and `onify_app_helix_envs`. Select a root-proxy build that serves `/` and forwards `/api/v2/`. |
| `onify_gateway_image`, `onify_gateway_envs` | Carry over the gateway image, settings and required secrets. | Map `onify_hub_gateway_image` and `onify_hub_gateway_envs` if deployed. Otherwise select and configure a Citizen gateway. Inventory consumers of Functions, Agent and the legacy Hub app and agree how each will be served before cutover. |

Both sources can have separate API hosts, tenant aliases or callbacks. Record every hostname **and path**, including `/helix`, SSO and webhooks. The target's `custom_hostname` sends each alias to the app. Move API consumers to `https://<app-host>/api/v2/` or arrange an explicit compatibility route for callers that need their old URL. Map each tenant alias in Citizen and update the identity provider's callback URLs. [Hostname formats](#public-hostnames-on-dev1) · [Legacy and custom domain runbook](https://github.com/onify/gke-to-hostup/blob/main/docs/operate.md#legacy-and-custom-domains)

### Rehearse, cut over and retain a rollback path

1. **Inventory the source.** The Terraform owner records the backend, workspace, namespace, images, replica counts, scheduled jobs and host mappings. Identify the actual Elasticsearch endpoint (including external databases), version, index prefix, data size and bound PVC/PV where applicable. Back up state and secrets privately. Confirm the target version can restore the snapshot and the target volume has capacity; the dev1 profile requests a 10 GiB claim. [Source inventory procedure](https://github.com/onify/gke-to-hostup/blob/main/docs/full-migration-waves.md#repeat-the-planning-inventory)

   From the migration repository, set `CFG` to the reviewed JSON configuration for this namespace. Inspect the plan offline, then check the running GKE Elasticsearch version, identity and snapshot plugin with the source credentials.

   ```sh
   python3 scripts/migrate_namespace.py plan --config "${CFG:?Set CFG to the namespace configuration}"
   python3 scripts/migrate_namespace.py source-backup-check --config "$CFG"
   ```

2. **Choose who owns the target resources.** With `environment_profile`, the module manages its own database, policies and routes. If the platform manages the target database and routes, use the application-only layout from `sok-dev`. Omit `environment_profile` and `custom_hostname`, set `elasticsearch_address` to the restored Service if needed, and configure aliases in the platform routing root. The module manages its namespace in both modes. For existing dev1 objects, reconcile ownership with their current state owner before applying. Check that the target plan preserves the namespace and any existing data claim. [Sokigo infrastructure handoff](https://github.com/onify/sok-dev-infra/pull/1)

3. **Restore a rehearsal copy in isolation.** The migration operator takes an Elasticsearch snapshot and restores it to a fresh dev1 volume with writers, jobs and outgoing integrations paused. Compare index names, mappings, aliases, document counts and representative records. The standard template starts the API, app, gateway and worker and publishes hostnames. Follow the staged restore procedure before opening the application. Setting `worker_replicas = 0` alone leaves the API running. [Snapshot and restore commands](https://github.com/onify/gke-to-hostup/blob/main/docs/snapshot-transfer.md) · [Sokigo rehearsal](https://github.com/onify/gke-to-hostup/blob/main/results/2026-11-25-sok-dev-migration.md)

4. **Freeze GKE and transfer the final data.** In the agreed maintenance window, pause incoming writes, drain queues, stop writers and suspend schedules and automation that could restart them. Keep Elasticsearch up for a fresh final snapshot. Verify zero failed shards, restore onto fresh target storage, and compare the restored indices and counts with the frozen source. If the preview has already accepted writes, preserve both copies and have the application owner reconcile them before selecting the authoritative database. [Cutover and source-stop procedure](https://github.com/onify/gke-to-hostup/blob/main/docs/full-migration-waves.md#rehearsal-cutover-and-source-stop)

5. **Switch traffic and verify the instance.** The platform owner updates the instance's routes, certificates and any DNS records that need to move. For every retained host, verify trusted HTTPS, HTML at `/` and JSON at `/api/v2/public/settings`. The application owner signs in to each tenant, checks a known record and tests required callbacks. Enable writes and jobs on dev1 only, then verify one controlled write or job completes once. Keep GKE workloads stopped across the next scheduled reconciliation. [Sokigo cutover and acceptance](https://github.com/onify/gke-to-hostup/blob/main/results/2026-11-25-sok-dev-cutover.md)

**Rollback and retirement.** Before dev1 accepts writes, the operator can restore the GKE routes, callbacks, replica counts and schedules against the retained source volume. After the first dev1 write, freeze dev1 and reconcile new records, queued work and external effects before reopening GKE. Retain the source state, disks and final snapshot until the application owner accepts the migration and off-server recovery has been tested. Retire only this instance's resources after the agreed retention period. Shared GKE infrastructure needs a separate decision covering its remaining users. [Rollback procedure](https://github.com/onify/gke-to-hostup/blob/main/docs/full-migration-waves.md#rollback)

## Remove an instance on dev1

From the same deployment directory, review the destroy plan for the intended namespace. **Deleting the namespace also deletes its Elasticsearch claim and resources created there outside this module.** Back up any data you need before applying the plan.

```sh
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

## Module configuration

In the calling root, configure the Kubernetes provider and set the four image references and `onify_api_envs`. The API client code and instance determine the namespace. The API and worker use `http://<client>-<instance>-elasticsearch:9200` by default. Override `elasticsearch_address` to use another service. The four workloads default to `image_pull_policy = "Always"`. Set it to `"IfNotPresent"` or `"Never"` to override the default. Supply `gcr_registry_keyfile` to pull private images from `eu.gcr.io`. Set `worker_replicas` to scale background processing.

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

`terraform destroy` also removes the instance's routes, listeners and Certificate resources. In the shared Gateway namespace, cert-manager retains generated TLS Secrets by default. [cert-manager cleanup behavior](https://cert-manager.io/docs/usage/certificate/#cleaning-up-secrets-when-certificates-are-deleted)
