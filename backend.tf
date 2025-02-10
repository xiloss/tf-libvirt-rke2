#
# terraform requirements
terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }
}
#
# libvirt provider configuration
provider "libvirt" {
  uri = "qemu:///system"
}
