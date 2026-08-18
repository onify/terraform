

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


