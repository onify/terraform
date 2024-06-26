example use to create gke cluster

```
module "gke" {
  source           = "github.com/onify/install//terraform/modules/gke"
  name			   = "onify-example-gke"
  gce_project_id   = "gce-something-project-id
  gce_region	   = "europe-north1"
  gke_num_nodes    = 1
  gke_username     = "username"    
  gke_password     = "password"
  fixed_outside_ip = false
}
```


#fixed outside ip is optional, if you want to have a fixed ip for the cluster set it to true.
For a public cluster we might need to deploy a ip masq agent. This can be done with the following manifests:
Info:
_https://niravshah2705.medium.com/public-gke-with-fixed-outbound-ip-e1f9e67845fc_

1. configmap:
```
nonMasqueradeCIDRs:
  - 0.0.0.0/0
masqLinkLocal: true
resyncInterval: 60s
```
Save to file "config" and apply with:
```
kubectl create configmap ip-masq-agent --from-file config --namespace kube-system
```

2. Daemonset for masq agent

manifest:
```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ip-masq-agent
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: ip-masq-agent
  template:
    metadata:
      labels:
        k8s-app: ip-masq-agent
    spec:
      hostNetwork: true
      containers:
      - name: ip-masq-agent
        image: gcr.io/google-containers/ip-masq-agent-amd64:v2.4.1
        args:
            - --masq-chain=IP-MASQ
            # To non-masquerade reserved IP ranges by default, uncomment the line below.
            # - --nomasq-all-reserved-ranges
        securityContext:
          privileged: true
        volumeMounts:
          - name: config
            mountPath: /etc/config
      volumes:
        - name: config
          configMap:
            # Note this ConfigMap must be created in the same namespace as the
            # daemon pods - this spec uses kube-system
            name: ip-masq-agent
            optional: true
            items:
              # The daemon looks for its config in a YAML file at /etc/config/ip-masq-agent
              - key: config
                path: ip-masq-agent
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - effect: NoExecute
        operator: Exists
      - key: "CriticalAddonsOnly"
        operator: "Exists"

```
Save to file "ip-masq-agent.yaml" and apply with:
```
kubectl apply -f ip-masq-agent.yaml
```



