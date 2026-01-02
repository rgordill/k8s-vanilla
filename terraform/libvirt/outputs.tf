# =============================================================================
# Outputs for Ansible Dynamic Inventory
# =============================================================================

output "vm_name" {
  description = "Name of the deployed VM"
  value       = libvirt_domain.k8s_node.name
}

output "vm_ip" {
  description = "IP address of the VM"
  value       = var.ip
}

output "ssh_user" {
  description = "SSH user for the VM"
  value       = var.ssh_user
}

output "ssh_private_key_file" {
  description = "Path to SSH private key"
  value       = replace(var.ssh_public_key_file, ".pub", "")
}

output "network_name" {
  description = "Name of the libvirt network"
  value       = libvirt_network.k8s_network.name
}

output "hostname" {
  description = "Hostname of the VM"
  value       = var.hostname
}

# Output for Ansible inventory
output "ansible_inventory" {
  description = "Ansible inventory data"
  value = {
    k8s_nodes = {
      hosts = {
        (var.hostname) = {
          ansible_host                 = var.ip
          ansible_user                 = var.ssh_user
          ansible_ssh_private_key_file = replace(var.ssh_public_key_file, ".pub", "")
          ansible_python_interpreter   = "/usr/bin/python3"
        }
      }
    }
  }
}



