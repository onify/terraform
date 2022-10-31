example use to create a gcs bucket

```
module "gke" {
  source           = "github.com/onify/install//terraform/modules/gke"
  name			   = "onify-example-gke"
  gce_project_id   = "gce-something-project-id
  gce_region	   = "europe-north1"
  gke_num_nodes    = 1
  gke_username     = "username"    
  gke_password     = "password"
}
```