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
  checks_file    = "tests/fixtures/checks.yml"
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
    condition     = yamldecode(output.cloud_init_metadata).network.ethernets.primary.match.name == "e*"
    error_message = "without a fixed MAC the interface is matched by name"
  }

  assert {
    condition     = [for e in output.checks.can_i_reach_endpoints : e.name] == ["gateway-ping", "dns-tcp", "syslog-udp", "api-https"]
    error_message = "the suite from checks_file must reach the guest intact"
  }

  assert {
    condition     = output.checks.can_i_reach_fail_on == "fail" && output.checks.can_i_reach_report_path == "/var/lib/can-i-reach/report.yml"
    error_message = "the fail_on policy and report path must be injected into the suite"
  }

  assert {
    condition     = startswith(output.cloud_init_userdata, "#cloud-config\n")
    error_message = "userdata must be a cloud-config document"
  }

  assert {
    condition     = flatten(yamldecode(trimprefix(output.cloud_init_userdata, "#cloud-config\n")).runcmd) == ["/usr/local/bin/can-i-reach-install", "/usr/local/bin/can-i-reach-run"]
    error_message = "install_tooling defaults to true: installer then runner"
  }

  assert {
    condition     = contains([for f in yamldecode(trimprefix(output.cloud_init_userdata, "#cloud-config\n")).write_files : f.path], "/etc/can-i-reach/checks.yml")
    error_message = "the suite file must be written into the guest"
  }

  assert {
    condition     = length(terraform_data.verdict) == 1
    error_message = "wait_for_result defaults to true"
  }
}

run "static_ip_plan" {
  command = plan

  variables {
    ipv4_address    = "10.40.1.50/24"
    ipv4_gateway    = "10.40.1.1"
    dns_servers     = ["10.40.0.10", "10.40.0.11"]
    dns_search      = ["corp.example"]
    mac_address     = "00:50:56:AB:CD:EF"
    install_tooling = false
    wait_for_result = false
    checks_file     = ""
    checks = {
      can_i_reach_endpoints = [{ name = "inline-tcp", host = "10.40.2.11", port = 1433 }]
    }
  }

  assert {
    condition     = yamldecode(output.cloud_init_metadata).network.ethernets.primary.addresses == ["10.40.1.50/24"]
    error_message = "the static address must land in the network config"
  }

  assert {
    condition     = yamldecode(output.cloud_init_metadata).network.ethernets.primary.routes[0].via == "10.40.1.1"
    error_message = "the default route must land in the network config"
  }

  assert {
    condition     = yamldecode(output.cloud_init_metadata).network.ethernets.primary.nameservers.search == ["corp.example"]
    error_message = "DNS search domains must land in the network config"
  }

  assert {
    condition     = yamldecode(output.cloud_init_metadata).network.ethernets.primary.match.macaddress == "00:50:56:ab:cd:ef"
    error_message = "with a fixed MAC the interface is matched by MAC"
  }

  assert {
    condition     = output.vm_ip == "10.40.1.50"
    error_message = "the verdict is read from the static address"
  }

  assert {
    condition     = flatten(yamldecode(trimprefix(output.cloud_init_userdata, "#cloud-config\n")).runcmd) == ["/usr/local/bin/can-i-reach-run"]
    error_message = "install_tooling=false must skip the installer"
  }

  assert {
    condition     = output.checks.can_i_reach_endpoints[0].name == "inline-tcp"
    error_message = "inline checks must be written"
  }

  assert {
    condition     = length(terraform_data.verdict) == 0
    error_message = "wait_for_result=false must not create the remote-exec step"
  }
}

run "inline_overrides_file" {
  command = plan

  variables {
    checks = {
      can_i_reach_endpoints = [{ name = "only-me", host = "10.40.9.9", port = 22 }]
      can_i_reach_timeout   = 9
    }
  }

  assert {
    condition     = length(output.checks.can_i_reach_endpoints) == 1 && output.checks.can_i_reach_timeout == 9
    error_message = "inline keys must win over the file per key"
  }

  assert {
    condition     = output.checks.can_i_reach_repo_enabled == false
    error_message = "file keys not overridden inline must survive"
  }
}

run "proxy_defaults_under_the_suite" {
  command = plan

  variables {
    proxy_url = "http://proxy.corp.example:3128"
    no_proxy  = ["10.40.0.0/16", ".corp.example"]
  }

  assert {
    condition     = output.checks.can_i_reach_proxy == "http://proxy.corp.example:3128"
    error_message = "proxy_url must become the suite's default proxy"
  }

  assert {
    condition     = jsonencode(output.checks.can_i_reach_no_proxy) == jsonencode(["10.40.0.0/16", ".corp.example"])
    error_message = "no_proxy must become can_i_reach_no_proxy"
  }

  assert {
    condition     = strcontains(output.cloud_init_userdata, "PROXY_URL=http://proxy.corp.example:3128")
    error_message = "the tooling install must see the proxy"
  }
}

run "suite_proxy_wins_over_module_proxy" {
  command = plan

  variables {
    proxy_url = "http://proxy.corp.example:3128"
    checks    = { can_i_reach_proxy = "http://other.example:8080" }
  }

  assert {
    condition     = output.checks.can_i_reach_proxy == "http://other.example:8080"
    error_message = "a suite that sets its own proxy keeps it"
  }
}

run "proxy_for_checks_false_keeps_suite_clean" {
  command = plan

  variables {
    proxy_url        = "http://proxy.corp.example:3128"
    proxy_for_checks = false
  }

  assert {
    condition     = !contains(keys(output.checks), "can_i_reach_proxy")
    error_message = "proxy_for_checks=false must not touch the suite"
  }
}

run "empty_suite_is_rejected" {
  command = plan

  variables {
    checks_file = ""
    checks      = {}
  }

  expect_failures = [vsphere_virtual_machine.this]
}
