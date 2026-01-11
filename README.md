# Terraform + Ansible: Single Node Kubernetes with kubeadm

This project deploys a single-node Kubernetes cluster using kubeadm on a Fedora VM. Supports multiple infrastructure providers (**libvirt/KVM** for local VMs or **AWS** for cloud). The infrastructure is provisioned with Terraform and configured with Ansible.

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
│  │  terraform   │    │  (libvirt or │    │  Kubernetes  │  │
│  │  init/apply  │    │  AWS EC2)    │    │  via kubeadm │  │
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
│   ├── libvirt/                  # Libvirt/KVM provider
│   │   ├── main.tf               # VM, network, storage resources
│   │   ├── variables.tf          # Input variables
│   │   ├── outputs.tf            # Outputs for Ansible inventory
│   │   ├── providers.tf          # Libvirt provider config
│   │   └── templates/
│   │       ├── cloud-init-userdata.yaml
│   │       └── cloud-init-networkdata.yaml
│   └── aws/                      # AWS provider
│       ├── main.tf               # VPC, EC2 instance resources
│       ├── variables.tf          # Input variables
│       ├── outputs.tf            # Outputs for Ansible inventory
│       ├── providers.tf          # AWS provider config
│       └── templates/
│           └── cloud-init-userdata.yaml
│
├── ansible/                      # Configuration Management
│   ├── ansible.cfg               # Ansible configuration
│   ├── requirements.yml          # Required Ansible collections
│   ├── inventory/
│   │   ├── group_vars/
│   │   │   └── all.yml           # Global variables (including terraform_provider)
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

### Common Requirements

1. **Terraform** >= 1.0
   ```bash
   terraform version
   ```

2. **Ansible** >= 2.14
   ```bash
   ansible --version
   ```

### For Libvirt Provider (local VMs)

3. **libvirt/KVM** installed and running
   ```bash
   sudo systemctl status libvirtd
   ```

4. **Fedora Cloud image** downloaded
   ```bash
   sudo wget -O /var/lib/libvirt/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2 \
     https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2
   ```

### For AWS Provider (cloud)

3. **AWS CLI** configured with credentials
   ```bash
   aws configure
   # Or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
   ```

4. **SSH key pair** available (default: `~/.ssh/id_rsa.pub`)

## Infrastructure Provider Selection

This project supports two infrastructure providers: **libvirt** (local VMs) and **aws** (cloud).

### Configuration

Set the provider in `ansible/inventory/group_vars/all.yml`:

```yaml
# Options: 'libvirt' (local VMs) or 'aws' (cloud)
terraform_provider: libvirt
```

### Provider Selection Priority

The provider is determined in the following order (highest priority first):

| Priority | Source | Description |
|----------|--------|-------------|
| 1 | `group_vars/all.yml` | `terraform_provider` variable in Ansible group_vars |
| 2 | Environment variable | `TERRAFORM_PROVIDER` environment variable |
| 3 | Auto-detect | Checks which provider has a `terraform.tfstate` file |
| 4 | Default | Falls back to `libvirt` |

### Override Examples

```bash
# Use group_vars setting (recommended)
# Edit ansible/inventory/group_vars/all.yml and set terraform_provider: aws

# Or override via environment variable
export TERRAFORM_PROVIDER=aws
ansible-playbook playbooks/site.yml

# Or override via extra vars (highest precedence for playbooks)
ansible-playbook playbooks/site.yml -e terraform_provider=aws
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

### 3. Select infrastructure provider

Edit `ansible/inventory/group_vars/all.yml`:

```yaml
terraform_provider: libvirt  # or 'aws' for cloud deployment
```

### 4. Configure variables (optional)

Edit `terraform/<provider>/terraform.tfvars` and `ansible/roles/kubernetes/defaults/main.yml` as needed.

### 5. Deploy everything

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
# Replace <provider> with 'libvirt' or 'aws'
cd terraform/<provider>
terraform init
terraform plan
terraform apply
terraform destroy
```

## Accessing the Cluster

### SSH into the VM

```bash
# Libvirt (default static IP)
ssh fedora@192.168.160.10

# AWS (get public IP from terraform output)
cd terraform/aws && terraform output vm_ip
ssh fedora@<public-ip>
```

### Get kubeconfig

```bash
# Replace <ip> with your VM's IP address
scp fedora@<ip>:/home/fedora/.kube/config ./kubeconfig
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

### Global Variables (`ansible/inventory/group_vars/all.yml`)

| Variable | Description | Default |
|----------|-------------|---------|
| `terraform_provider` | Infrastructure provider (`libvirt` or `aws`) | `libvirt` |
| `pod_network_cidr` | Pod network CIDR | `10.244.0.0/16` |
| `service_cidr` | Service network CIDR | `10.96.0.0/12` |

### Libvirt Terraform Variables (`terraform/libvirt/terraform.tfvars`)

| Variable | Description | Default |
|----------|-------------|---------|
| `hostname` | VM hostname | `k8s-node` |
| `ip` | Static IP | `192.168.160.10` |
| `memory` | RAM in MB | `8192` |
| `vcpus` | CPU cores | `4` |
| `main_disk_size` | Disk size | `30GB` |

### AWS Terraform Variables (`terraform/aws/terraform.tfvars`)

| Variable | Description | Default |
|----------|-------------|---------|
| `hostname` | EC2 instance name | `k8s-node` |
| `instance_type` | EC2 instance type | `t3.large` |
| `aws_region` | AWS region | `eu-west-1` |
| `root_volume_size` | Root volume size (GB) | `30` |
| `ssh_public_key_file` | SSH public key path | `~/.ssh/id_rsa.pub` |

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
# For libvirt
cd terraform/libvirt
terraform output -json

# For AWS
cd terraform/aws
terraform output -json
```

### VM issues (libvirt)

```bash
virsh list --all
virsh console k8s-node
```

### EC2 issues (AWS)

```bash
# Check instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=k8s-node"

# SSH into instance (get IP from terraform output)
ssh fedora@<public-ip>
```

### Kubernetes issues

```bash
ssh fedora@192.168.160.10
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
