#
locals {
  libvirt_network_name                = var.stack_config.libvirt_network_name
  libvirt_network_mode                = var.stack_config.libvirt_network_mode
  libvirt_network_domain              = var.stack_config.libvirt_network_domain
  libvirt_network_addresses           = var.stack_config.libvirt_network_addresses
  libvirt_network_bridge_name         = var.stack_config.libvirt_network_bridge_name
  libvirt_network_dns_servers         = var.stack_config.libvirt_network_dns_servers
  libvirt_network_gateway             = var.stack_config.libvirt_network_gateway
  libvirt_network_masters_ips         = var.stack_config.libvirt_network_masters_ips
  libvirt_cloudinit_disk_masters_name = var.stack_config.libvirt_cloudinit_disk_masters_name
  libvirt_volume_masters_disk_name    = var.stack_config.libvirt_volume_masters_disk_name
  libvirt_volume_masters_disk_pool    = var.stack_config.libvirt_volume_masters_disk_pool
  libvirt_volume_masters_disk_size    = var.stack_config.libvirt_volume_masters_disk_size
  libvirt_volume_masters_disk_format  = var.stack_config.libvirt_volume_masters_disk_format
  libvirt_domain_masters_count        = length(var.stack_config.libvirt_network_masters_ips)
  libvirt_domain_masters_name         = var.stack_config.libvirt_domain_masters_name
  libvirt_domain_masters_memory       = var.stack_config.libvirt_domain_masters_memory
  libvirt_domain_masters_vcpu         = var.stack_config.libvirt_domain_masters_vcpu
  libvirt_network_agents_ips          = var.stack_config.libvirt_network_agents_ips
  libvirt_cloudinit_disk_agents_name  = var.stack_config.libvirt_cloudinit_disk_agents_name
  libvirt_volume_agents_disk_name     = var.stack_config.libvirt_volume_agents_disk_name
  libvirt_volume_agents_disk_pool     = var.stack_config.libvirt_volume_agents_disk_pool
  libvirt_volume_agents_disk_size     = var.stack_config.libvirt_volume_agents_disk_size
  libvirt_volume_agents_disk_format   = var.stack_config.libvirt_volume_agents_disk_format
  libvirt_domain_agents_count         = length(var.stack_config.libvirt_network_agents_ips)
  libvirt_domain_agents_name          = var.stack_config.libvirt_domain_agents_name
  libvirt_domain_agents_memory        = var.stack_config.libvirt_domain_agents_memory
  libvirt_domain_agents_vcpu          = var.stack_config.libvirt_domain_agents_vcpu
}
#
# A pool for all cluster volumes
resource "libvirt_pool" "rke2" {
  name = "rke2"
  type = "dir"
  target {
    path = "/home/xiloss/cluster_storage"
  }
}
#
# Random string of fixed length to provide a token to the RKE2 cluster
resource "random_string" "rke2_token" {
  length  = 48
  special = false
}
#
# Volume for the base OS image
resource "libvirt_volume" "ubuntu_image" {
  name = "ubuntu-22.04.qcow2"
  pool = libvirt_pool.rke2.name
  # slower to download the source image each time, better a static file
  # source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  source = "ubuntu-22.04-server-cloudimg-amd64.img" # Path to your downloaded image
  format = "qcow2"
}
#
# Create libvirt network for the RKE2 cluster
resource "libvirt_network" "rke2_network" {
  name   = local.libvirt_network_name
  mode   = local.libvirt_network_mode
  domain = local.libvirt_network_domain
  # bridge = local.libvirt_network_bridge_name
  addresses = local.libvirt_network_addresses
  dhcp {
    enabled = false # Disable DHCP if using static IPs
  }
  dns {
    enabled = true
  }
}
#
# Create a cloud-init disk for the master node
resource "libvirt_cloudinit_disk" "rke2_master_init" {
  count          = local.libvirt_domain_masters_count
  name           = format("%s-%v.iso", local.libvirt_cloudinit_disk_masters_name, count.index)
  user_data      = data.template_file.rke2_master_cloudinit[count.index].rendered
  network_config = data.template_file.rke2_master_network_config[count.index].rendered
}
#
# RKE2 Master Disk
resource "libvirt_volume" "rke2_master_disk" {
  count = local.libvirt_domain_masters_count
  name  = format("%s-%v.%s", local.libvirt_volume_masters_disk_name, count.index, local.libvirt_volume_masters_disk_format)
  # pool   = local.libvirt_volume_masters_disk_pool
  pool           = libvirt_pool.rke2.name
  size           = local.libvirt_volume_masters_disk_size
  base_volume_id = libvirt_volume.ubuntu_image.id
  format         = local.libvirt_volume_masters_disk_format
}
#
# RKE2 Master Node
resource "libvirt_domain" "rke2_master" {
  count  = local.libvirt_domain_masters_count
  name   = format("%s-%v", local.libvirt_domain_masters_name, count.index)
  memory = local.libvirt_domain_masters_memory
  vcpu   = local.libvirt_domain_masters_vcpu

  cloudinit = libvirt_cloudinit_disk.rke2_master_init[count.index].id

  # Enable CPU host-passthrough for cases like kubevirt; it reduces portability
  # but it will easily allow nested virtualization.
  cpu {
    mode = "host-passthrough"
  }

  # Network interface based on e1000 emulation
  network_interface {
    network_name   = libvirt_network.rke2_network.name
    network_id     = libvirt_network.rke2_network.id
    mac            = data.template_file.rke2_master_network_config[count.index].vars.mac_address
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.rke2_master_disk[count.index].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
#
# Create cloud-init disks for the agent nodes
resource "libvirt_cloudinit_disk" "rke2_agent_init" {
  count          = local.libvirt_domain_agents_count
  name           = format("%s-%v.iso", local.libvirt_cloudinit_disk_agents_name, count.index)
  user_data      = data.template_file.rke2_agent_cloudinit[count.index].rendered
  network_config = data.template_file.rke2_agent_network_config[count.index].rendered
}
#
# RKE2 Agent Disk
resource "libvirt_volume" "rke2_agent_disk" {
  count = local.libvirt_domain_agents_count
  name  = format("%s-%v.%s", local.libvirt_volume_agents_disk_name, count.index, local.libvirt_volume_agents_disk_format)
  # pool   = local.libvirt_volume_agents_disk_pool
  pool           = libvirt_pool.rke2.name
  size           = local.libvirt_volume_agents_disk_size
  base_volume_id = libvirt_volume.ubuntu_image.id
  format         = local.libvirt_volume_agents_disk_format
}
#
# RKE2 Agent Nodes
resource "libvirt_domain" "rke2_agent" {
  count  = local.libvirt_domain_agents_count
  name   = format("%s-%v", local.libvirt_domain_agents_name, count.index)
  memory = local.libvirt_domain_agents_memory
  vcpu   = local.libvirt_domain_agents_vcpu

  cloudinit = libvirt_cloudinit_disk.rke2_agent_init[count.index].id

  # Enable CPU host-passthrough for cases like kubevirt; it reduces portability
  # but it will easily allow nested virtualization.
  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_name   = libvirt_network.rke2_network.name
    network_id     = libvirt_network.rke2_network.id
    mac            = data.template_file.rke2_agent_network_config[count.index].vars.mac_address
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.rke2_agent_disk[count.index].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
#