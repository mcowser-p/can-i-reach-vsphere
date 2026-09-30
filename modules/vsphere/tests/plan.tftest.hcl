# Plan-only tests against a mocked vSphere provider: no vCenter needed.
mock_provider "vsphere" {
  mock_data "vsphere_virtual_machine" {
    defaults = {
      guest_id                = "ubuntu64Guest"
      scsi_type               = "pvscsi"
      network_interface_types = ["vmxnet3"]
      disks                   = [{ label = "disk0", unit_number = 0, size = 20, thin_provisioned = true, eagerly_scrub = false }]
    }
  }
}

variables {
  datacenter     = "dc1"
  cluster        = "cluster1"
  datastore      = "ds1"
  network        = "vlan-40-app"
  template       = "ubuntu-24.04-cloudinit"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEY test@example"
  checks = {
    can_i_reach_endpoints = [{ name = "gateway-ping", host = "10.40.0.1", protocol = "icmp" }]
  }
}

run "dhcp_plan" {
  command = plan

  assert {
    condition     = vsphere_virtual_machine.this.network_interface[0].network_id == data.vsphere_network.vlan.id
    error_message = "the VM must attach to the VLAN port group"
  }

  assert {
    condition     = yamldecode(output.cloud_init_metadata).network.ethernets.primary.dhcp4 == true
    error_message = "no static address given, the guest should use DHCP"
  }

  assert {
    condition     = startswith(yamldecode(output.cloud_init_metadata)["instance-id"], "can-i-reach-preflight-")
    error_message = "the instance-id carries the suite hash"
  }

  assert {
    condition     = output.checks.can_i_reach_endpoints[0].name == "gateway-ping"
    error_message = "the suite must reach the guest"
  }

  assert {
    condition     = output.verdict_enabled
    error_message = "wait_for_result defaults to true"
  }
}

run "static_ip_plan" {
  command = plan

  variables {
    ipv4_address    = "10.40.1.50/24"
    ipv4_gateway    = "10.40.1.1"
    mac_address     = "00:50:56:AB:CD:EF"
    wait_for_result = false
  }

  assert {
    condition     = yamldecode(output.cloud_init_metadata).network.ethernets.primary.addresses == ["10.40.1.50/24"]
    error_message = "the static address must land in guestinfo metadata"
  }

  assert {
    condition     = output.vm_ip == "10.40.1.50"
    error_message = "the verdict is read from the static address"
  }

  assert {
    condition     = !output.verdict_enabled
    error_message = "wait_for_result=false must skip the verdict step"
  }
}
