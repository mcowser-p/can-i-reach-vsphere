locals {
  hostname  = var.hostname != "" ? var.hostname : var.vm_name
  static_ip = var.ipv4_address != ""

  # --- The suite: file first, inline over it, policy last ---
  # (list comprehensions instead of conditionals: object branches of a
  # conditional must share a type, and a suite has whatever keys it has)
  checks_from_file = merge([for f in compact([var.checks_file]) : yamldecode(file(f))]...)
  # Module-level proxy settings sit UNDER the file: a suite that sets
  # can_i_reach_proxy / can_i_reach_no_proxy itself keeps its own values.
  proxy_defaults = merge(
    [for p in(var.proxy_for_checks ? compact([var.proxy_url]) : []) : { can_i_reach_proxy = p }]...
  )
  no_proxy_defaults = merge(
    [for i in(var.proxy_for_checks && length(var.no_proxy) > 0 ? [1] : []) : { can_i_reach_no_proxy = var.no_proxy }]...
  )
  checks = merge(
    local.proxy_defaults,
    local.no_proxy_defaults,
    local.checks_from_file,
    var.checks,
    {
      can_i_reach_fail_on     = var.fail_on
      can_i_reach_report_path = var.report_path
    },
  )
  policy_keys = [
    "can_i_reach_fail_on", "can_i_reach_report_path", "can_i_reach_fail_fast",
    "can_i_reach_timeout", "can_i_reach_tries", "can_i_reach_checks", "can_i_reach_remediate",
  ]
  # Keys that actually describe something to test.
  check_keys = [for k in keys(local.checks) : k if startswith(k, "can_i_reach_") && !contains(local.policy_keys, k)]

  # --- Guest network (cloud-init network config v2) ---
  nic_pieces = concat(
    [for m in compact([var.mac_address]) : { match = { macaddress = lower(m) } }],
    [for i in(var.mac_address == "" ? [1] : []) : { match = { name = "e*" } }],
    [for i in(local.static_ip ? [1] : []) : { dhcp4 = false, addresses = [var.ipv4_address] }],
    [for i in(local.static_ip ? [] : [1]) : { dhcp4 = true }],
    [for gw in(local.static_ip ? compact([var.ipv4_gateway]) : []) : { routes = [{ to = "default", via = gw }] }],
    [for i in(local.static_ip && length(var.dns_servers) > 0 ? [1] : []) : {
      nameservers = merge(concat(
        [{ addresses = var.dns_servers }],
        [for j in(length(var.dns_search) > 0 ? [1] : []) : { search = var.dns_search }],
      )...)
    }],
  )
  nic = merge(local.nic_pieces...)

  # A new suite means a new instance-id, so cloud-init runs again on the
  # next boot instead of treating the VM as already provisioned.
  instance_id = "${var.vm_name}-${substr(sha256(yamlencode(local.checks)), 0, 12)}"

  metadata = yamlencode({
    "instance-id"    = local.instance_id
    "local-hostname" = local.hostname
    network = {
      version   = 2
      ethernets = { primary = local.nic }
    }
  })

  guest_env = join("\n", [
    "VENV=/opt/can-i-reach/venv",
    "COLLECTIONS=/opt/can-i-reach/collections",
    "STATE_DIR=/var/lib/can-i-reach",
    "LOG=/var/log/can-i-reach.log",
    "PLAYBOOK=/etc/can-i-reach/preflight.yml",
    "REPORT_PATH=${var.report_path}",
    "ANSIBLE_CORE_VERSION=${var.ansible_core_version}",
    "COLLECTION_SOURCE=${var.collection_source}",
    "PIP_INDEX_URL=${var.pip_index_url}",
    "PROXY_URL=${var.proxy_url}",
    "NO_PROXY_LIST=${join(",", var.no_proxy)}",
    "",
  ])

  playbook = yamlencode([{
    name         = "can-i-reach preflight (run from the VM itself)"
    hosts        = "localhost"
    connection   = "local"
    gather_facts = true
    vars_files   = ["/etc/can-i-reach/checks.yml"]
    roles        = ["mcowser_p.can_i_reach.can_i_reach"]
  }])

  userdata = join("\n", ["#cloud-config", yamlencode({
    hostname         = local.hostname
    manage_etc_hosts = true
    ssh_pwauth       = false
    users = [{
      name                = var.ssh_user
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      shell               = "/bin/bash"
      lock_passwd         = true
      ssh_authorized_keys = [var.ssh_public_key]
    }]
    write_files = [
      { path = "/etc/can-i-reach/env", permissions = "0644", content = local.guest_env },
      { path = "/etc/can-i-reach/checks.yml", permissions = "0644", content = yamlencode(local.checks) },
      { path = "/etc/can-i-reach/preflight.yml", permissions = "0644", content = local.playbook },
      { path = "/usr/local/bin/can-i-reach-install", permissions = "0755", content = file("${path.module}/scripts/install.sh") },
      { path = "/usr/local/bin/can-i-reach-run", permissions = "0755", content = file("${path.module}/scripts/run.sh") },
      { path = "/usr/local/bin/can-i-reach-wait", permissions = "0755", content = file("${path.module}/scripts/wait.sh") },
    ]
    runcmd = concat(
      var.install_tooling ? [["/usr/local/bin/can-i-reach-install"]] : [],
      [["/usr/local/bin/can-i-reach-run"]],
    )
    final_message = "can-i-reach: boot-time run finished after $UPTIME seconds"
  })])

  vm_ip = local.static_ip ? split("/", var.ipv4_address)[0] : vsphere_virtual_machine.this.default_ip_address
}
