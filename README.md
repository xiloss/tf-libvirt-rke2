# TERRAFORM LIBVIRT STACK FOR RKE2

## Introduction

For this deployment and additional components, the chosen host operating system is Ubuntu 22.04

## Requirements

When using ubuntu as host, there are some addtional configurations for qemu to set in order to work with the virtual disks and related permissions.

Apparmor review for the file /etc/apparmor.d/usr.lib.libvirt.virt-aa-helper will show that the defaults for the images path, generally at /var/lib/libvirt/images directory has an r attribute, and the same is for the inner files at /var/lib/libvirt/images/**. Instead of altering the configuration for this file, there is the reerence in the /etc/apparmor.d/libvirt/TEMPLATE.qemu file, where we can add custom paths, also considering we want to create additional libvirt storage pools.
Considering that we could create pools in different folders, something like /home/user/libvirt_clusters, the we can modify the file adding the following

```bash
#
# This profile is for the domain whose UUID matches this file.
#

#include <tunables/global>

profile LIBVIRT_TEMPLATE flags=(attach_disconnected) {
  #include <abstractions/libvirt-qemu>
  # Allow access to custom storage pool
  "/home/user/libvirt_clusters/" r,
  "/home/user/libvirt_clusters/**" rwk,
}
```

The operating system on the RKE2 cluster disk has to be downloaded, for that scope we are going to use the ubuntu cloud image. The server version of ubuntu 22.04 will be a perfect fit for RKE2.
It is generally used as the base for other kubernetes distributions, so downloading it once is enough.
It is also a requirement for the stack to work, since the given image is used as source for creating the cluster nodes volumes containing the operating system.

```bash
wget https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img
```

# Configure a local loadbalancer for the masters (optional)

This steps are not mandatory, but they are quite useful to loadbalance the masters and the kubernetes api to be reachable from the hosting machine.

## Install a local HAProxy

```bash
sudo apt update && sudo apt install -y haproxy
```

A configuration for HAProxy for this stack has to be added to the configuration file `/etc/haproxy/haproxy.cfg`, adding the following configuration:

```
frontend rke2_api
    bind *:6443
    mode tcp
    default_backend rke2_masters

backend rke2_masters
    mode tcp
    balance roundrobin
    option tcp-check
    server master1 192.168.122.10:6443 check
    server master2 192.168.122.11:6443 check
    server master3 192.168.122.12:6443 check
```

The three master IPs in the given configuration file have to be the same we have in the `variables.tf`.

After that configuration is completed, just restart the HAProxy service with `systemctl restart haproxy`

## Install a local bind DNS service

```bash
sudo apt install -y bind9
```

Edit the /etc/bind/named.conf.local bind configuration file, adding a reference to the new local zone:

```
zone "rke2.local" {
    type master;
    file "/etc/bind/db.rke2.local";
};
```

and finally creating the zone configuration file `/etc/bind/db.rke2.local`, adding the following:

```bind
$TTL 86400
@   IN  SOA ns.rke2.local. admin.rke2.local. (
        2024021901 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

@   IN  NS  ns.rke2.local.
ns  IN  A   192.168.122.1      ; IP of the current host with  the BIND service
rke2-api IN A   192.168.122.1  ; IP of HAProxy
```

NOTE: the referenced IP address is the local address we want to use to reach the endpoint.

Once the changes are committed, restart the bind service.

`systemctl restart bind9`


# Setup and provisioning

1. be sure to edit the variables.tf file with your consistent values. It could be necessary to review the network configuration, while the size of the virtual disks and machines resources should be the minimal requirement to run the demo.
