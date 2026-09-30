# Convert Onify Customer to Onify Citizen

Citizen keeps the existing namespace, Elasticsearch StatefulSet, and storage
resources so their Terraform state and data volumes stay attached. Other
workloads are replaced with the simplified names. Plan a cutover window for the
frontend and API.
Update callers that used the old Service names; Citizen uses the fixed names
`onify-citizen-app`, `onify-citizen-api`, `onify-citizen-gateway`, and
`onify-citizen-elasticsearch` within each namespace. Remove any Service naming
arguments from the module call. Remove any external Functions hostname;
Gateway has no public Ingress.
The API hostname stays the same, but its Ingress
and backend are replaced during the cutover.

## 1. Preserve the data identity

Use the same Terraform backend, workspace, Kubernetes provider target, and
root module label. Copy the **entire** previous `onify_hub_api_envs` map to
`onify_api_envs`, especially `ONIFY_client_code`, `ONIFY_client_instance`, and
`ONIFY_db_indexPrefix`. Keep every `elasticsearch_*` input and `gke` at its
previous value. Changing the client identity, storage mode, or index prefix
can point the new API at different data or plan replacement of storage.

Take an Elasticsearch snapshot or storage backup and save a secure state copy
outside the repository. Terraform state contains secrets.

## 2. Rename the inputs in the same module block

Change the module `source` from `//modules/onify-customer` to
`//modules/onify-citizen` without renaming the root module block. Map inputs:

| Previous input | Citizen input |
|---|---|
| `onify_hub_api_envs` | `onify_api_envs` (same complete map) |
| `onify_hub_api_image` | `onify_api_image` (required) |
| `onify_hub_worker_image` | `onify_worker_image` (omit when it used the API image) |
| `onify_hub_functions_image` | Remove; provide `onify_gateway_image` instead (required) |
| `onify_helix_image` | `onify_app_image` (required GCR frontend image built for `/`) |
| `onify_app_helix_envs` | `onify_app_envs` (only values used by the browser frontend) |
| `onify_hub_gateway_image`, `onify_hub_gateway_envs` | `onify_gateway_image`, `onify_gateway_envs` |
| `onify_hub_api_*`, `onify_hub_worker_*` resource, TLS, and access settings | matching `onify_api_*`, `onify_worker_*` inputs |
| `onify_hub_functions_*` settings | Remove; configure Gateway with `onify_gateway_*` inputs |
| `onify_hub_app_tls` | `onify_app_tls`, when a custom TLS secret is used |
| `onify_helix_*` resource settings | matching `onify_app_*` settings |

Remove the old app, Agent, mode, path, and GitHub registry arguments. Do not
carry internal API/app URL environment values into the frontend. The existing
`/helix` route is removed; Citizen serves the frontend at `/`. Image pull
credentials in Citizen cover GCR only.

## 3. Check the actual plan

From the existing deployment root:

```sh
terraform init
terraform validate
terraform plan
```

Expect the old app, API, worker, Functions, Agent, and their Services or
Ingresses to be removed or replaced. The Elasticsearch Service is renamed;
Terraform creates the new Service before deleting the old one. Its ClusterIP
and allocated NodePorts can change. The Elasticsearch StatefulSet retains its
existing `serviceName` to avoid replacement.
Expect creation of the Citizen app, API, worker, and Gateway. The image
pull-secret also drops the old registry entry. The namespace,
Elasticsearch StatefulSet, data and backup PVCs, and local PVs (when used) must
show **no destroy or replace**.
Stop if the plan proposes that; correct the input values, backend/workspace,
or provider target before applying. `prevent_destroy` guards the namespace and
Elasticsearch volumes while their resource configuration remains present.

With the same root module label, Elasticsearch resource addresses do not
change. No `state mv`, `state rm`, or import is needed. If a label change is
unavoidable, add a root-level move for the **whole** module before planning:

```hcl
moved {
  from = module.old_customer_label
  to   = module.new_citizen_label
}
```
