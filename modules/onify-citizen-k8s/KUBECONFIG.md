# Connect to a Kubernetes cluster

A VPN can make a private Kubernetes API reachable. The cluster determines how you sign in. A kubeconfig can use single sign-on (SSO), a token or a client certificate. A personal certificate is only needed if your cluster uses certificate authentication for your account. [Kubernetes authentication methods](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#authentication-methods)

## Create a new kubeconfig

1. Ask your cluster administrator for the **Kubernetes API URL**, the **sign-in method for your account**, and the **server CA certificate** if the API uses a private certificate authority. An API URL might look like `https://192.0.2.10:6443` or `https://api.example.com:6443`. Use the actual host and port they give you. For an IP address, the server's TLS certificate must include that IP. If it lists a DNS name instead, use that name in the URL.
2. Choose the matching example below and save a copy as `cluster.config` in a private directory outside Git. Open it in a text editor and replace the `server` URL. Both examples refer to credential files beside `cluster.config`. The example YAML files can be shared as supplied. Distribute credentials separately through your approved channel.
3. Add the files for your sign-in method, then [verify the connection](#connect-with-your-kubeconfig).

| Sign-in method | What to put beside `cluster.config` |
| --- | --- |
| [Bearer token — no client certificate](examples/kubeconfig-token.yaml) | Save the token issued for your account in `token.txt` as a single line, without quotes or a `Bearer` prefix. Renew it when it expires. The example uses your system's trusted CAs. For a private CA, add `ca.crt` and uncomment `certificate-authority: ca.crt`. |
| [Client certificate and private key](examples/kubeconfig-client-cert.yaml) | Save your issued PEM client certificate as `client.crt` and its matching key as `client.key`. The example also expects `ca.crt` to verify the server. If your system already trusts the server, remove the `certificate-authority` line. If you need a new client certificate, [request one from the administrator](#request-a-client-certificate). |

If your cluster uses SSO, use the kubeconfig and login plugin supplied by your identity provider or cluster administrator.

## Connect with your kubeconfig

Install [kubectl](https://kubernetes.io/docs/tasks/tools/) and connect to the network or VPN your cluster requires. Run these commands from the directory containing `cluster.config`. If you already have a kubeconfig, substitute its path, quoting paths that contain spaces.

```text
kubectl --kubeconfig=cluster.config config get-contexts
kubectl --kubeconfig=cluster.config config view --minify -o "jsonpath={.clusters[0].cluster.server}"
kubectl --kubeconfig=cluster.config version
```

The asterisk marks the active context. Check that the URL matches the intended cluster and that `version` reports a **Server Version**. To switch contexts, run `kubectl --kubeconfig=cluster.config config use-context my-context` with a name from your file. For Citizen, `kubectl --kubeconfig=cluster.config auth can-i create namespaces` checks one permission the module needs. A `no` means you should ask the administrator about deployment access.

## Use the same file in Terraform

In your deployment's copy of `main.tf`, replace the entire `provider "kubernetes"` block with the example below. Set the path to the file you verified. Here, `~` means your home directory.

```hcl
provider "kubernetes" {
  config_path = pathexpand("~/cluster-access/cluster.config")
}
```

Removing the template's `host` and `config_context` settings lets the provider use the server and active context in your file. To share one `main.tf` across users with different file locations, use `provider "kubernetes" {}` and set `KUBE_CONFIG_PATH` to the full local path in each user's environment. Keep the `required_providers` declaration in both cases. [Kubernetes provider configuration](https://registry.terraform.io/providers/hashicorp/kubernetes/2.24.0/docs)

For a new Citizen deployment on another cluster, use a separate Terraform state. Set `environment_profile` to a profile installed on that cluster, or omit it for an application-only deployment. [Cluster-managed environments](README.md#cluster-managed-environments)

## Request a client certificate

If your administrator asks for a certificate signing request (CSR), run these OpenSSL commands in a new private directory. At the Common Name prompt, enter your assigned username. At the Organization prompt, enter a single dot (`.`) to leave it empty unless your administrator specifies a group. [Kubernetes client certificate authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certificates)

```text
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out client.key
openssl req -new -key client.key -out client.csr
```

Send only `client.csr` to the administrator for signing. Keep `client.key` private. Save the returned PEM certificate as `client.crt`, then use it with the [client certificate example](examples/kubeconfig-client-cert.yaml).
