# =============================================================================
# Outputs for Ansible Dynamic Inventory
# =============================================================================

output "vm_name" {
  description = "Name of the deployed instance"
  value       = aws_instance.k8s_node.tags["Name"]
}

output "vm_ip" {
  description = "Public IP address of the instance"
  value       = aws_eip.k8s_node.public_ip
}

output "vm_private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.k8s_node.private_ip
}

output "ssh_user" {
  description = "SSH user for the instance"
  value       = var.ssh_user
}

output "ssh_private_key_file" {
  description = "Path to SSH private key"
  value       = replace(var.ssh_public_key_file, ".pub", "")
}

output "hostname" {
  description = "Hostname of the instance"
  value       = var.hostname
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.k8s_vpc.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = aws_subnet.k8s_public.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.k8s_node.id
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = local.ami_id
}

# Output for Ansible inventory
output "ansible_inventory" {
  description = "Ansible inventory data"
  value = {
    k8s_nodes = {
      hosts = {
        (var.hostname) = {
          ansible_host                 = aws_eip.k8s_node.public_ip
          ansible_user                 = var.ssh_user
          ansible_ssh_private_key_file = replace(var.ssh_public_key_file, ".pub", "")
          ansible_python_interpreter   = "/usr/bin/python3"
          private_ip                   = aws_instance.k8s_node.private_ip
        }
      }
    }
  }
}

