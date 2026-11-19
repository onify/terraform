# Onify Citizen

Onify Citizen runs one Helix frontend, API, worker, and Gateway in the
`<client>-<instance>` Kubernetes namespace. Elasticsearch
stores the customer's data. The browser uses same-origin routes; the module
sets `ONIFY_API_URL_INTERNAL` for the frontend container's NGINX proxy.

| Component | Image input | Workload name | Service | Port |
|---|---|---|---|---|
| API | `onify_api_image` | `<client>-<instance>-api` | `onify-citizen-api` | 8181 |
| App | `onify_app_image` | `<client>-<instance>-app` | `onify-citizen-app` | 4000, routed at `/` |
| Worker | `onify_worker_image` (defaults to API image) | `<client>-<instance>-worker` | none | background process |
| Gateway | `onify_gateway_image` | `<client>-<instance>-gateway` | `onify-citizen-gateway` | 8686 |
| Elasticsearch | `elasticsearch_version` | `<client>-<instance>-elasticsearch` | `onify-citizen-elasticsearch` | 9200 |

Set `onify_api_envs.ONIFY_client_code`, `ONIFY_client_instance`, and
`ONIFY_db_indexPrefix` for each installation. The first two determine the
namespace and resource names; the index prefix selects the existing
Elasticsearch data. App, API, and Gateway images are required. Set
`gcr_registry_keyfile` for the GCR image pull-secret. Gateway has no public Ingress.
Service names are fixed as shown above. Within the same namespace, call
Gateway at `http://onify-citizen-gateway:8686`.
StatefulSet `service_name` fields keep their existing values to avoid replacing
running workloads when the Services are renamed.

See [the example](examples/main.tf) for a module call and
[migration from Onify Customer](MIGRATION.md) for the
storage-safe conversion and expected resource replacements.
