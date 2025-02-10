#
# Output master details
output "masters" {
  value = libvirt_domain.rke2_master.*
}
#
# Output agent details
output "agents" {
  value = libvirt_domain.rke2_agent.*
}
#
# Output libvirt pool details
output "storage_pool" {
  value = libvirt_pool.rke2
}
#
# Output master IP address
# output "master_ips" {
#   value = [
#     for i in libvirt_domain.rke2_master :
#     i.network_interface.*.addresses
#   ]
# }
#
# Output agent IP addresses
# output "agent_ips" {
#   value = [
#     for i in libvirt_domain.rke2_agent :
#     i.network_interface.*.addresses
#   ]
# }
#
# RKE2 cluster token
output "rke2_token" {
  value     = random_string.rke2_token.result
  sensitive = true
}