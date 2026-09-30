# Deploys one throwaway VM onto a vSphere port group and proves, from
# inside that VM, that everything in checks.yml is reachable (and that
# everything marked expect: unreachable is blocked). `tofu apply` fails
# when a check fails; `tofu destroy` removes the VM.

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}

module "preflight" {
  source = "../../modules/vsphere"
  # From a release instead:
  # source = "git::https://github.com/mcowser-p/can-my-server-reach.git//modules/vsphere?ref=v2"

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
