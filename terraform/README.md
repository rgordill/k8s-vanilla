# Terraform Infrastructure

This directory contains Terraform configurations for provisioning Kubernetes infrastructure on different cloud providers.

## Providers

### Libvirt (Local VMs)

For local development using libvirt/KVM virtual machines.

```bash
cd libvirt
cp terraform.tfvars.example terraform.tfvars  # if needed
terraform init
terraform plan
terraform apply
```

**Requirements:**
- libvirt/KVM installed
- Fedora Cloud image downloaded (or set `download_image = true`)

### AWS

For cloud deployment on Amazon Web Services.

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
terraform init
terraform plan
terraform apply
```

**Requirements:**
- AWS CLI configured with credentials
- SSH key pair

## Ansible Integration

The Terraform outputs are consumed by the Ansible dynamic inventory. Set the `TERRAFORM_PROVIDER` environment variable to specify which provider to use:

```bash
# For libvirt
export TERRAFORM_PROVIDER=libvirt
ansible-playbook -i inventory/terraform_inventory.py playbooks/site.yml

# For AWS
export TERRAFORM_PROVIDER=aws
ansible-playbook -i inventory/terraform_inventory.py playbooks/site.yml
```

If not set, the inventory script will auto-detect based on which provider has a `terraform.tfstate` file.

## Outputs

Both providers output compatible data for Ansible:

| Output | Description |
|--------|-------------|
| `vm_name` | Name of the instance |
| `vm_ip` | IP address (public for AWS) |
| `ssh_user` | SSH username |
| `hostname` | Hostname of the instance |
| `ansible_inventory` | Full inventory data for Ansible |

