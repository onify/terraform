# Onify Citizen

Onify Citizen runs one Helix frontend, API, worker, Functions, and an optional
Gateway in the `<client>-<instance>` Kubernetes namespace. Elasticsearch
stores the customer's data. The browser uses same-origin routes; the module
sets `ONIFY_API_URL_INTERNAL` for the frontend container's NGINX proxy.

| Component | Image input | Workload name | Service | Port |
|---|---|---|---|---|
| API | `onify_api_image` | `<client>-<instance>-api` | `api` | 8181 |
| App | `onify_app_image` | `<client>-<instance>-app` | `app` | 4000, routed at `/` |
| Worker | `onify_worker_image` (defaults to API image) | `<client>-<instance>-worker` | none | background process |
| Functions | `onify_functions_image` | `<client>-<instance>-functions` | `functions` | 8282 |
| Gateway | `onify_gateway_image` (optional) | `<client>-<instance>-gateway` | `gateway` | 8686 |
| Elasticsearch | `elasticsearch_version` | `<client>-<instance>-elasticsearch` | `elasticsearch` | 9200 |

Set `onify_api_envs.ONIFY_client_code`, `ONIFY_client_instance`, and
`ONIFY_db_indexPrefix` for each installation. The first two determine the
namespace and resource names; the index prefix selects the existing
Elasticsearch data. App, API, and Functions images are required. Set
`gcr_registry_keyfile` for the GCR image pull-secret. Gateway is disabled
until `onify_gateway_image` is provided, and has no public Ingress.
Within the same namespace, call Gateway at `http://gateway:8686`.

See [the example](examples/main.tf) for a module call, [Gateway](gateway.md)
for its settings, and [migration from Onify Customer](MIGRATION.md) for the
storage-safe conversion and expected resource replacements.
