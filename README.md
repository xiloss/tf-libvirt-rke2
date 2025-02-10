# TERRAFORM LIBVIRT STACK FOR RKE2

## Introduction

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