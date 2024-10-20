

## elasticsearch backup

requires kubectl locally

To enable elasticsearch backup att variables:
```
  elasticsearch_backup_schedule = "0 0/30 * * *"
  elasticsearch_backup_enabled = true
```

This will add a persistent volume claim to the elasticsearch statefulset and a nullresource to create a slm policy to backup the snapshots.
Backups will be saved at /usr/share/elasticsearch/backups

If elasticsearch_backup_schedule is changed the nullresource will be triggered to update slm policy


