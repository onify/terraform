

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


