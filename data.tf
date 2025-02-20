# variables parsing
locals {
  rke2_version     = var.stack_config.rke2_version
  calico_version   = var.stack_config.calico_version
  rke2_cni         = var.stack_config.rke2_cni
  install_kubevirt = var.stack_config.install_kubevirt
  install_custom_kubectl = var.stack_config.install_custom_kubectl

}
# cloud-init user-data for master nodes template
data "template_file" "rke2_master_cloudinit" {
  count    = local.libvirt_domain_masters_count
  template = file("${path.module}/templates/rke2_master.tpl.yaml")
  vars = {
    hostname         = format("%s-%v", local.libvirt_domain_masters_name, count.index)
    ssh_public_key   = file("id_ed25519.pub")
    token            = random_string.rke2_token.result
    server_url       = count.index == 0 ? "" : format("https://%s:9345", local.libvirt_network_masters_ips[0])
    cluster_init     = count.index == 0 ? true : false
    cni              = local.rke2_cni
    rke2_version     = local.rke2_version
    calico_version   = local.calico_version
    install_kubevirt = local.install_kubevirt
    install_custom_kubectl = local.install_custom_kubectl
  }
}
#
# Master Network Config
data "template_file" "rke2_master_network_config" {
  count    = local.libvirt_domain_masters_count
  template = file("${path.module}/templates/network_config.cfg")
  vars = {
    mac_address = format("AA:BB:CC:DD:EE:%02d", count.index + 1)
    ip_address  = local.libvirt_network_masters_ips[count.index]
    gateway     = local.libvirt_network_gateway
    dns_servers = format("%s", jsonencode(local.libvirt_network_dns_servers))
  }
}
#
# cloud-init user-data for agent nodes template
data "template_file" "rke2_agent_cloudinit" {
  count    = local.libvirt_domain_agents_count
  template = file("${path.module}/templates/rke2_agent.tpl.yaml")

  vars = {
    hostname       = format("%s-%v", local.libvirt_domain_agents_name, count.index)
    ssh_public_key = file("id_ed25519.pub")
    token          = random_string.rke2_token.result
    server_url     = format("https://%s:9345", local.libvirt_network_masters_ips[0])
    rke2_version   = local.rke2_version
  }
}
#
# Agent Network Config
data "template_file" "rke2_agent_network_config" {
  count    = local.libvirt_domain_agents_count
  template = file("${path.module}/templates/network_config.cfg")
  vars = {
    mac_address = format("AA:BB:CC:DD:EE:%02d", count.index + local.libvirt_domain_masters_count + 1)
    ip_address  = local.libvirt_network_agents_ips[count.index]
    gateway     = local.libvirt_network_gateway
    dns_servers = format("%s", jsonencode(local.libvirt_network_dns_servers))
  }
}
#