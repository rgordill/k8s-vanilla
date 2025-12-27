# Terraform + Ansible: Single Node Kubernetes with kubeadm

This project deploys a single-node Kubernetes cluster using kubeadm on a Fedora VM running on libvirt/KVM. The infrastructure is provisioned with Terraform and configured with Ansible.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Workflow                            │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Ansible    │───▶│  Terraform   │───▶│   Ansible    │  │
│  │  provision   │    │    apply     │    │  configure   │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                   │                    │          │
│         ▼                   ▼                    ▼          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Run         │    │  Create VM   │    │  Install     │  │
│  │  terraform   │    │  on libvirt  │    │  Kubernetes  │  │
│  │  init/apply  │    │  + network   │    │  via kubeadm │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                             │                               │
│                             ▼                               │
│                    ┌──────────────────┐                     │
│                    │  Dynamic         │                     │
│                    │  Inventory from  │                     │
│                    │  tfstate         │                     │
│                    └──────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
k8s-vanilla/
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # VM, network, storage resources
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Outputs for Ansible inventory
│   ├── providers.tf              # Libvirt provider config
│   ├── terraform.tfvars          # Variable values
│   └── templates/
│       ├── cloud-init-userdata.yaml
│       └── cloud-init-networkdata.yaml
│
├── ansible/                      # Configuration Management
│   ├── ansible.cfg               # Ansible configuration
│   ├── requirements.yml          # Required Ansible collections
│   ├── inventory/
│   │   └── terraform_inventory.py    # Dynamic inventory from tfstate
│   ├── playbooks/
│   │   ├── site.yml              # Main playbook (provision + configure)
│   │   ├── provision.yml         # Terraform provisioning
│   │   ├── configure.yml         # Kubernetes configuration
│   │   └── destroy.yml           # Teardown infrastructure
│   └── roles/
│       ├── kubernetes/           # Kubernetes installation role
│       │   ├── defaults/main.yml
│       │   ├── tasks/
│       │   │   ├── main.yml
│       │   │   ├── prerequisites.yml
│       │   │   ├── crio.yml
│       │   │   ├── kubernetes.yml
│       │   │   ├── kubeadm_init.yml
│       │   │   ├── cni.yml
│       │   │   └── post_install.yml
│       │   ├── handlers/main.yml
│       │   └── templates/
│       │       ├── kubeadm-config.yaml.j2
│       │       ├── crio-crun.conf.j2
│       │       └── crio-cgroup.conf.j2
│       └── argocd/               # ArgoCD Core installation role
│           ├── defaults/main.yml
│           ├── tasks/main.yml
│           └── handlers/main.yml
│
└── README.md
```

## Prerequisites

1. **libvirt/KVM** installed and running
   ```bash
   sudo systemctl status libvirtd
   ```

2. **Terraform** >= 1.0
   ```bash
   terraform version
   ```

3. **Ansible** >= 2.14
   ```bash
   ansible --version
   ```

4. **Fedora Cloud image** downloaded
   ```bash
   sudo wget -O /var/lib/libvirt/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2 \
     https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2
   ```

## Quick Start

### 1. Install Ansible collections

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### 2. Make inventory script executable

```bash
chmod +x ansible/inventory/terraform_inventory.py
```

### 3. Configure variables (optional)

Edit `terraform/terraform.tfvars` and `ansible/roles/kubernetes/defaults/main.yml` as needed.

### 4. Deploy everything

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

This will:
1. Initialize and apply Terraform to create the VM
2. Use dynamic inventory from Terraform state
3. Configure Kubernetes using Ansible
4. Deploy ArgoCD Core for GitOps

## Usage

### Full deployment (provision + configure)

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

### Provision infrastructure only

```bash
cd ansible
ansible-playbook playbooks/provision.yml
```

### Configure Kubernetes only (VM must exist)

```bash
cd ansible
ansible-playbook playbooks/configure.yml
```

### Destroy infrastructure

```bash
cd ansible
ansible-playbook playbooks/destroy.yml
```

### Manual Terraform operations

```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform destroy
```

## Accessing the Cluster

### SSH into the VM

```bash
ssh fedora@192.168.200.10
```

### Get kubeconfig

```bash
scp fedora@192.168.200.10:/home/fedora/.kube/config ./kubeconfig
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

## Components Installed

- **Fedora 42** Cloud Base image (kernel 6.14)
- **CRI-O** container runtime with **crun** OCI runtime
- **kubeadm, kubelet, kubectl** - Kubernetes v1.35
- **Flannel** CNI for pod networking
- **CoreDNS** for cluster DNS
- **ArgoCD Core** for GitOps (Application Controller, Repo Server, Redis)

## Configuration

### Terraform Variables (`terraform/terraform.tfvars`)

| Variable | Description | Default |
|----------|-------------|---------|
| `hostname` | VM hostname | `k8s-node` |
| `ip` | Static IP | `192.168.200.10` |
| `memory` | RAM in MB | `8192` |
| `vcpus` | CPU cores | `4` |
| `main_disk_size` | Disk size | `30GB` |

### Kubernetes Variables (`ansible/roles/kubernetes/defaults/main.yml`)

| Variable | Description | Default |
|----------|-------------|---------|
| `kubernetes_version` | K8s version | `1.35` |
| `pod_network_cidr` | Pod CIDR | `10.244.0.0/16` |
| `container_runtime` | Runtime | `crio` |
| `oci_runtime` | OCI runtime | `crun` |
| `cni_plugin` | CNI plugin | `flannel` |
| `coredns_replicas` | CoreDNS replicas | `1` |

### ArgoCD Variables (`ansible/roles/argocd/defaults/main.yml`)

| Variable | Description | Default |
|----------|-------------|---------|
| `argocd_chart_version` | Helm chart version | `7.7.16` |
| `argocd_namespace` | Namespace | `argocd` |
| `argocd_release_name` | Helm release name | `argocd` |
| `argocd_core_install` | Core install (no UI) | `true` |
| `argocd_ready_timeout` | Deployment timeout | `300` |

## Troubleshooting

### Check Ansible inventory

```bash
cd ansible
./inventory/terraform_inventory.py --list
```

### Check Terraform state

```bash
cd terraform
terraform output -json
```

### VM issues

```bash
virsh list --all
virsh console k8s-node
```

### Kubernetes issues

```bash
ssh fedora@192.168.200.10
sudo journalctl -u kubelet -f
kubectl get pods -A
crictl info
```

### ArgoCD issues

```bash
kubectl get pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## Using ArgoCD Core

ArgoCD Core is a lightweight installation without the UI/API server. Manage applications using kubectl:

### Create an Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Check Application Status

```bash
kubectl get applications -n argocd
kubectl describe application my-app -n argocd
```
