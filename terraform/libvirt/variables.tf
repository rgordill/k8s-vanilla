# =============================================================================
# Libvirt Provider Configuration
# =============================================================================

variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_name" {
  description = "The name of the network"
  type        = string
  default     = "local-nat"
}

variable "use_existing_network" {
  description = "Whether to use an existing network instead of creating one"
  type        = bool
  default     = false
}

variable "network_mode" {
  description = "The mode of the network (nat, route, bridge)"
  type        = string
  default     = "nat"
}

variable "network_cidr" {
  description = "The CIDR block for the network"
  type        = string
  default     = "192.168.160.0/24"
}

variable "domain" {
  description = "The domain name for the network"
  type        = string
  default     = "k8s.local"
}

# =============================================================================
# Virtual Machine Configuration
# =============================================================================

variable "hostname" {
  description = "The hostname for the VM"
  type        = string
  default     = "k8s-node"
}

variable "ip" {
  description = "The IP address for the VM"
  type        = string
  default     = "192.168.160.10"
}

variable "mac_address" {
  description = "The MAC address for the VM (optional, leave empty for auto)"
  type        = string
  default     = ""
}

variable "memory" {
  description = "The amount of memory for the VM in MB"
  type        = number
  default     = 8192
}

variable "vcpus" {
  description = "The number of CPUs for the VM"
  type        = number
  default     = 4
}

variable "main_disk_size" {
  description = "The size of the main disk in bytes"
  type        = number
  default     = 32212254720  # 30GB
}

# =============================================================================
# Image Configuration
# =============================================================================

variable "image_base" {
  description = "The base image name for the VM"
  type        = string
  default     = "Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
}

variable "image_source" {
  description = "The source URL for the base image"
  type        = string
  default     = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
}

variable "download_image" {
  description = "Whether to download the base image (set to false if already downloaded)"
  type        = bool
  default     = false
}

# =============================================================================
# Authentication
# =============================================================================

variable "ssh_public_key_file" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_user" {
  description = "SSH user for the VM"
  type        = string
  default     = "fedora"
}

variable "password" {
  description = "Password for the fedora user"
  type        = string
  sensitive   = true
  default     = "changeme"
}



