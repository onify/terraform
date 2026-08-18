# Helix-Only Terraform Design

## Scope

Add an explicit Helix-only deployment mode to `modules/onify-customer`. The default remains the current hybrid topology and legacy-only installations remain supported.

## Modes

- `helix = false`, `helix_only = false`: legacy module.
- `helix = true`, `helix_only = false`: current hybrid module.
- `helix = true`, `helix_only = true`: Helix service owns root routing and the legacy app workload/service is absent.
- `helix = false`, `helix_only = true`: invalid.

In Helix-only mode both `/` and `/helix` reach the Helix service on port 4000. The root-built citizen image is responsible for redirecting legacy `/helix/...` browser paths to their root equivalents. API, worker, agent, functions, and Elasticsearch resources are unchanged.

The Helix container receives `ONIFY_API_URL_INTERNAL` pointing at the existing `<client>-<instance>-hub-api:8181` Kubernetes service so the root proxy image can reach the API.

## Compatibility

`helix_only` defaults to `false` at both module layers. Tests cover all valid modes, the invalid combination, default root routing to port 3000, Helix-only root routing to port 4000, custom host rules, and legacy `/helix` routing.
