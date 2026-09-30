# Deploys one throwaway VM onto a VLAN and proves, from inside that VM,
# that everything in checks.yml is reachable. `tofu apply` fails when a
# check fails; `tofu destroy` removes the VM. See ../../README.md.

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}

module "preflight" {
  source = "../../"
  # From a release instead:
  # source = "git::https://github.com/mcowser-p/can-i-reach-vsphere.git?ref=v1.0.0"

  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = var.folder
  template   = var.template
  network    = var.network # the VLAN under test

  vm_name      = var.vm_name
  ipv4_address = var.ipv4_address
  ipv4_gateway = var.ipv4_gateway
  dns_servers  = var.dns_servers

  ssh_public_key  = var.ssh_public_key
  ssh_private_key = var.ssh_private_key

  checks_file = "${path.root}/checks.yml"
  fail_on     = "fail"
}

output "vm_ip" {
  value = module.preflight.vm_ip
}

output "read_verdict_without_ssh" {
  value = module.preflight.guestinfo_command
}
