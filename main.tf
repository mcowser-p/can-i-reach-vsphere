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
    "guestinfo.userdata"          = base64encode(local.userdata)
    "guestinfo.userdata.encoding" = "base64"
  }

  # "Routable" would require a default gateway; an isolated VLAN may
  # legitimately have none. An IP reported by VMware Tools is enough.
  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = var.guest_ip_timeout

  lifecycle {
    precondition {
      condition     = length(local.check_keys) > 0
      error_message = "The check suite is empty: checks_file/checks must define at least one can_i_reach_* list (e.g. can_i_reach_endpoints)."
    }
  }
}

# Blocks until the boot-time run has finished, replays its log into the
# apply output, and fails the apply with the suite's exit code.
resource "terraform_data" "verdict" {
  count = var.wait_for_result ? 1 : 0

  triggers_replace = [vsphere_virtual_machine.this.id, local.instance_id]

  connection {
    type        = "ssh"
    host        = local.vm_ip
    port        = var.ssh_port
    user        = var.ssh_user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    agent       = var.ssh_private_key == ""
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /usr/local/bin/can-i-reach-wait ${var.result_timeout_seconds}",
    ]
  }
}
