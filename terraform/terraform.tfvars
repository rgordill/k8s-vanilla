# =============================================================================
# Libvirt Kubernetes Node Configuration
# =============================================================================

# Libvirt connection
libvirt_uri = "qemu:///system"

# Network configuration
network_name = "k8s-network"
network_mode = "nat"
network_cidr = "192.168.200.0/24"
domain       = "k8s.local"

# Virtual Machine settings
hostname       = "k8s-node"
ip             = "192.168.200.10"
mac_address    = ""  # Leave empty for auto-generated MAC
memory         = 8192  # 8GB RAM
vcpus          = 4
main_disk_size = 32212254720  # 30GB

# Fedora Cloud image (Fedora 42 with kernel 6.14 - recommended for kubeadm)
# Set download_image = true on first run if the image doesn't exist
download_image = false
image_base     = "Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
image_source   = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"

# Authentication
ssh_public_key_file = "~/.ssh/id_rsa.pub"
ssh_user            = "fedora"
password            = "changeme"



