locals {
  hostname = var.hostname != "" ? var.hostname : var.vm_name
}

module "cloud_init" {
  source = "../cloud-init"

  hostname       = local.hostname
  ssh_user       = var.ssh_user
  ssh_public_key = var.ssh_public_key

  ipv4_address = var.ipv4_address
  ipv4_gateway = var.ipv4_gateway
  dns_servers  = var.dns_servers
  dns_search   = var.dns_search
  mac_address  = var.mac_address

  checks_file = var.checks_file
  checks      = var.checks
  fail_on     = var.fail_on
  report_path = var.report_path

  install_tooling      = var.install_tooling
  ansible_core_version = var.ansible_core_version
  collection_source    = var.collection_source
  pip_index_url        = var.pip_index_url

  proxy_url        = var.proxy_url
  no_proxy         = var.no_proxy
  proxy_for_checks = var.proxy_for_checks
}

data "vsphere_datacenter" "this" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "this" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_resource_pool" "this" {
  count         = var.resource_pool != "" ? 1 : 0
  name          = "${var.cluster}/Resources/${var.resource_pool}"
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_datastore" "this" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.this.id
}

# The VLAN under test.
data "vsphere_network" "vlan" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template
  datacenter_id = data.vsphere_datacenter.this.id
}

locals {
  # A new suite means a new instance-id, so cloud-init runs again on the
  # next boot instead of treating the VM as already provisioned.
  instance_id = "${var.vm_name}-${module.cloud_init.suite_hash}"

  metadata = yamlencode({
    "instance-id"    = local.instance_id
    "local-hostname" = local.hostname
    network          = module.cloud_init.network_config
  })
}

resource "vsphere_virtual_machine" "this" {
  name             = var.vm_name
  resource_pool_id = var.resource_pool != "" ? data.vsphere_resource_pool.this[0].id : data.vsphere_compute_cluster.this.resource_pool_id
  datastore_id     = data.vsphere_datastore.this.id
  folder           = var.folder != "" ? var.folder : null
  annotation       = var.annotation

  num_cpus  = var.num_cpus
  memory    = var.memory_mb
  guest_id  = data.vsphere_virtual_machine.template.guest_id
  firmware  = coalesce(var.firmware, data.vsphere_virtual_machine.template.firmware, "bios")
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id     = data.vsphere_network.vlan.id
    adapter_type   = try(data.vsphere_virtual_machine.template.network_interface_types[0], "vmxnet3")
    mac_address    = var.mac_address != "" ? var.mac_address : null
    use_static_mac = var.mac_address != ""
  }

  disk {
    label            = "disk0"
    size             = coalesce(var.disk_size_gb, try(data.vsphere_virtual_machine.template.disks[0].size, 20))
    thin_provisioned = try(data.vsphere_virtual_machine.template.disks[0].thin_provisioned, true)
    eagerly_scrub    = try(data.vsphere_virtual_machine.template.disks[0].eagerly_scrub, false)
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  # cloud-init's VMware datasource reads these guestinfo keys on first boot.
  extra_config = {
    "guestinfo.metadata"          = base64encode(local.metadata)
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(module.cloud_init.user_data)
    "guestinfo.userdata.encoding" = "base64"
  }

  # "Routable" would require a default gateway; an isolated VLAN may
  # legitimately have none. An IP reported by VMware Tools is enough.
  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = var.guest_ip_timeout
}

locals {
  vm_ip = coalesce(module.cloud_init.static_ip, vsphere_virtual_machine.this.default_ip_address)
}

module "verdict" {
  source = "../verdict"

  enabled                = var.wait_for_result
  host                   = local.vm_ip
  instance_id            = vsphere_virtual_machine.this.id
  suite_hash             = module.cloud_init.suite_hash
  ssh_user               = var.ssh_user
  ssh_port               = var.ssh_port
  ssh_private_key        = var.ssh_private_key
  result_timeout_seconds = var.result_timeout_seconds
}
