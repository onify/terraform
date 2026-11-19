

# Hub Gateway

Set `onify_hub_gateway_image` to add Hub Gateway to an existing Onify Customer
installation. Like Functions, it creates a StatefulSet and two internal Services:
`<client>-<instance>-hub-gateway` and the alias `hub-gateway`, both on port 8686.
It is disabled by default.
Use `onify_hub_gateway_envs` for additional environment variables; `PORT` is
always 8686. The service is reachable inside the namespace at
`http://hub-gateway:8686`.

Use `onify_hub_gateway_memory_limit`, `onify_hub_gateway_cpu_limit`,
`onify_hub_gateway_memory_requests`, and `onify_hub_gateway_cpu_requests` to
configure resources, as with Functions. Set `onify_hub_gateway_external = true`
to add an ingress when `ingress = true`; it uses `tls`, `external_dns_domain`,
and `custom_hostname` like Functions. Override its TLS secret with
`onify_hub_gateway_tls`.

Existing gateway Deployments are replaced by StatefulSets on the next apply;
review the plan for this workload transition before applying.

## Run Gateway without Functions

Start Gateway by setting `onify_hub_gateway_image`. Update and verify any
callers that still use Functions. Set `onify_hub_functions_enabled` to `false`
to remove the Functions StatefulSet, both Services, and its Ingress if present.
Functions stays enabled by default. Gateway works with all frontend modes,
including `helix_only = true`.

## Move an existing deployment off `consolidate`

Keep the same module block label, Terraform backend and workspace, Kubernetes
provider target, client code, instance, and Elasticsearch index prefix. For the
first plan, also keep the cluster type, disk size and running Elasticsearch
version. Check any settings previously inherited from `consolidate` defaults,
including Elasticsearch version and external Functions access.

For an installation whose Elasticsearch StatefulSet still has the data
`volumeClaimTemplates` entry, use the default branch source with the legacy
storage option in the existing module block.

```hcl
source                       = "github.com/onify/terraform//modules/onify-customer"
elasticsearch_legacy_storage = true
```

Installations that already manage `kubernetes_persistent_volume_claim.elasticsearch_data[0]`
in Terraform state use the default storage option. An installation with
external Elasticsearch also uses the default.

Take a verified backup and record the bound data PVC and PV names and UIDs.
Run `terraform init` and `terraform plan` against the existing deployment. With
legacy storage, the plan should keep the existing data claim template and
show no standalone data PVC creation. Require no delete or replacement for the
namespace, Elasticsearch StatefulSet, or any PVC or PV. The PVC created by
Kubernetes is visible via `kubectl get pvc`. Compare its UID and bound PV UID
after the cutover and verify that the same Elasticsearch indices are accessible.

Once the source update is verified, enable Gateway-only or Helix-only with
their own settings. Keep the legacy storage setting for as long as the
existing StatefulSet owns the data claim template.

# elasticsearch backup

### prerequisites
requires kubectl locally

To enable elasticsearch backup add variable:

```
  elasticsearch_backup_enabled = true
```

Set custom schedule by setting variable:
```
  elasticsearch_backup_schedule = "0 0/30 * * *"
```

This will add a persistent volume claim to the elasticsearch statefulset and a nullresource to create a slm policy to backup the snapshots.
Backups will be saved at /usr/share/elasticsearch/backups

If `elasticsearch_backup_schedule` is changed the nullresource will be triggered to update slm policy

# Helix-only deployment

The module supports these modes. `helix_only` is opt-in and defaults to `false`.

| Mode | Variables | Workloads and routing |
|---|---|---|
| Legacy only | `helix = false`, `helix_only = false` | The legacy app owns `/`; the Helix submodule is absent. |
| Hybrid (default when Helix is enabled) | `helix = true`, `helix_only = false` | The legacy app owns `/`; Helix owns `/helix`. |
| Helix only | `helix = true`, `helix_only = true` | The legacy app is absent; Helix owns both `/` and `/helix`. |

`helix_only = true` is rejected unless `helix = true`. Running the module tests requires Terraform 1.11.4 or later because their mocked providers use `override_during = plan`; the deployed module retains its existing `> 1.5` compatibility constraint.

Set the following only after the selected Helix image has been built for root-path proxy operation:

```hcl
helix             = true
helix_only        = true
onify_helix_image = "eu.gcr.io/onify-images/citizen/app-root:<citizen-app-commit-sha>"
```

The Citizen App GitHub Actions workflows publish `citizen/app-root` automatically. Point `onify_helix_image` directly at its commit-SHA tag. This removes the legacy app StatefulSet and service and routes both `/` and `/helix` to the Helix service. The `/helix` route is retained for existing shortcuts and bookmarks.

In Helix-only mode, the container receives the module-owned `ONIFY_API_URL_INTERNAL` as the internal API origin without `/api/v2`; the root proxy image appends the appropriate API and authentication paths. This variable is not injected in hybrid mode, and callers must not override it in Helix-only mode.

Before applying the cutover, review the plan and require only these mode-specific transitions:

- the legacy app StatefulSet and service are destroyed;
- root and custom-host `/` backends move from the legacy service on port 3000 to the Helix service on port 4000;
- `/helix` remains on the Helix service on port 4000.

Keep `onify_hub_app_image` pinned to the previous deployable image for rollback even though the workload is absent in Helix-only mode.

## Roll back to hybrid

Set `helix_only = false`, retain `helix = true`, and plan again. The expected rollback recreates the legacy app StatefulSet and service, routes `/` back to port 3000, and leaves `/helix` on Helix port 4000. Confirm the retained `onify_hub_app_image` still resolves before applying. Do not apply if the plan changes unrelated workloads, storage, secrets, or networking.


