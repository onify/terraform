resource "google_compute_instance" "onify" { 
  name         = var.name
  machine_type = var.machine_type
  zone         = var.gce_zone
  tags         = [var.name]

  boot_disk {
    initialize_params {
      image = var.os_image
      size = var.disk_size
      type = var.disk_type
    }
  }
  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }
  metadata = {
    ssh-keys = join("\n", [for key in var.ssh_keys : "${key.user}:${key.publickey}"])
    user-data = <<EOF
#cloud-config
# - microk8s enable dashboard dns storage

#
# (2) Wait until microk8s is fully up.
#
# (3) Initialize optional microk8s components.
#
snap:
  commands:
    00: snap install microk8s --classic --channel=${var.microk8sChannel}
    05: snap install kubectl --classic --channel=${var.microk8sChannel}

runcmd:
- iptables -P FORWARD ACCEPT
- microk8s status --wait-ready
- microk8s enable dns
- microk8s enable ingress 
- cp /tmp/csr.conf.template /var/snap/microk8s/current/certs/csr.conf.template
- microk8s refresh-certs
- mkdir -p /usr/share/elasticsearch/data
- chown 1000:2000 /usr/share/elasticsearch/data 

write_files:
- path: /etc/bash.bashrc
  content: |
    # set up Kubernetes

    if [ ! -d ~/.kube ]
    then
      echo Creating ~/.kube/config...
      mkdir -p ~/.kube
      microk8s config > ~/.kube/config
    fi

    export CLUSTER_CONTEXT=`kubectl config current-context`
    export KUBECONFIG_PATH=~/.kube/config
  append: true

- path: /tmp/csr.conf.template
  content: |
    [ req ]
    default_bits = 2048
    prompt = no
    default_md = sha256
    req_extensions = req_ext
    distinguished_name = dn

    [ dn ]
    C = GB
    ST = Canonical
    L = Canonical
    O = Canonical
    OU = Canonical
    CN = 127.0.0.1

    [ req_ext ]
    subjectAltName = @alt_names

    [ alt_names ]   
    DNS.1 = kubernetes
    DNS.2 = kubernetes.default
    DNS.3 = kubernetes.default.svc
    DNS.4 = kubernetes.default.svc.cluster
    DNS.5 = kubernetes.default.svc.cluster.local
    DNS.6 = ${var.name}.${var.domain}
    IP.1 = 127.0.0.1
    IP.2 = 10.152.183.1
    #MOREIPS

    [ v3_ext ]
    authorityKeyIdentifier=keyid,issuer:always
    basicConstraints=CA:FALSE
    keyUsage=keyEncipherment,dataEncipherment,digitalSignature
    extendedKeyUsage=serverAuth,clientAuth
    subjectAltName=@alt_names
EOF
  }
}

data "google_dns_managed_zone" "dns" {
  name = var.gcp_dns_zone
}

resource "google_dns_managed_zone" "zone" {
  name     = var.name
  dns_name = "${var.name}.${data.google_dns_managed_zone.dns.dns_name}"
  description = "terraform managed zone for ${var.name}"
}
resource "google_dns_record_set" "zone_subzone_ns" {
  name = "${var.name}.${data.google_dns_managed_zone.dns.dns_name}"
  type = "NS"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.dns.name

  rrdatas = google_dns_managed_zone.zone.name_servers
}

#Creates a host record. Could be in subdomain but more clean to have it in a topdomain
resource "google_dns_record_set" "host" {
  name = "${google_dns_managed_zone.zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.zone.name

  rrdatas = [google_compute_instance.onify.network_interface[0].access_config[0].nat_ip]
}

#This will forward all dns to the host
resource "google_dns_record_set" "wildcard" {
  name = "*.${google_dns_managed_zone.zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.zone.name

  rrdatas = [google_compute_instance.onify.network_interface[0].access_config[0].nat_ip]
}


resource "google_compute_firewall" "onify" {
name    = "${var.name}-firewall"
network = "default"
target_tags = [var.name]
source_ranges = ["0.0.0.0/0"] 
    allow {
        protocol = "tcp"
        ports    = ["80","443","22","16443","8080"]
    }
 
}

resource "null_resource" "kubeconfig" {
    triggers = {
        always_run = timestamp()
    }
    provisioner "remote-exec" {
        connection {
        host = "${google_compute_instance.onify.network_interface[0].access_config[0].nat_ip}"
        user = "ubuntu"
        }

        inline = ["echo 'connected!'"]
    }
    provisioner "local-exec" {
        command = "until ssh -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' ubuntu@${google_dns_managed_zone.zone.dns_name} sudo microk8s config > kubeconfig_${var.name}; do sleep 5; done"
    }
    provisioner "local-exec" {
        command = "KUBECONFIG=kubeconfig_${var.name} kubectl config set-cluster microk8s-cluster --server=https://${google_dns_managed_zone.zone.dns_name}:16443"
    }
    provisioner "local-exec" {
        command = "until KUBECONFIG=kubeconfig_${var.name} kubectl version; do sleep 30; done"
    }
    # provisioner "local-exec" {
    #     command = "export KUBE_CONFIG_PATH=kubeconfig_${var.name}"
    # }
    # provisioner "local-exec" {
    #     command = "export KUBECONFIG=kubeconfig_${var.name}"
    # }
    provisioner "local-exec" {
        when    = destroy
        command = "rm -rf kubeconfig_*"
    }
    depends_on = [
      google_compute_instance.onify
    ]
}
