# =============================================================================
# Libvirt Virtual Machine - Base VM for Kubernetes (configured by Ansible)
# =============================================================================

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

# Create network only if use_existing_network is false
resource "libvirt_network" "k8s_network" {
  count     = var.use_existing_network ? 0 : 1
  name      = var.network_name
  mode      = var.network_mode
  domain    = var.domain
  autostart = true

  addresses = [var.network_cidr]

  dns {
    enabled    = true
    local_only = false
  }
}

# Use existing network if use_existing_network is true
data "libvirt_network" "existing" {
  count = var.use_existing_network ? 1 : 0
  name  = var.network_name
}

locals {
  network_id = var.use_existing_network ? data.libvirt_network.existing[0].id : libvirt_network.k8s_network[0].id
}

# -----------------------------------------------------------------------------
# Base Image (optional download)
# -----------------------------------------------------------------------------

resource "libvirt_volume" "source_image" {
  count  = var.download_image ? 1 : 0
  name   = var.image_base
  source = var.image_source
}

# -----------------------------------------------------------------------------
# Main Disk Volume
# -----------------------------------------------------------------------------

resource "libvirt_volume" "main_disk" {
  name             = "${var.hostname}.qcow2"
  base_volume_name = var.image_base
  size             = var.main_disk_size
}

# -----------------------------------------------------------------------------
# Cloud-init Configuration (basic setup only, Kubernetes configured by Ansible)
# -----------------------------------------------------------------------------

resource "libvirt_cloudinit_disk" "cloudinit" {
  name = "${var.hostname}-cloudinit.iso"

  user_data = templatefile("${path.module}/templates/cloud-init-userdata.yaml", {
    hostname       = var.hostname
    password       = var.password
    ssh_public_key = file(var.ssh_public_key_file)
  })

  network_config = templatefile("${path.module}/templates/cloud-init-networkdata.yaml", {
    ip_address = var.ip
    gateway    = cidrhost(var.network_cidr, 1)
    dns_server = cidrhost(var.network_cidr, 1)
  })
}

# -----------------------------------------------------------------------------
# Virtual Machine Domain
# -----------------------------------------------------------------------------

resource "libvirt_domain" "k8s_node" {
  name   = var.hostname
  memory = var.memory
  vcpu   = var.vcpus

  cloudinit = libvirt_cloudinit_disk.cloudinit.id

  cpu {
    mode = "host-model"
  }

  disk {
    volume_id = libvirt_volume.main_disk.id
  }

  network_interface {
    network_id     = local.network_id
    addresses      = [var.ip]
    mac            = var.mac_address != "" ? var.mac_address : null
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = 0
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}



