locals {
  static_ip = var.ipv4_address != ""

  # --- The suite: module proxy defaults < file < inline < policy ---
  checks_from_file = merge([for f in compact([var.checks_file]) : yamldecode(file(f))]...)
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
    "can_i_reach_proxy", "can_i_reach_no_proxy",
  ]
  check_keys = [for k in keys(local.checks) : k if startswith(k, "can_i_reach_") && !contains(local.policy_keys, k)]
  suite_hash = substr(sha256(yamlencode(local.checks)), 0, 12)

  # --- Network config v2 (used by platforms that hand the guest its network) ---
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
  network_config = {
    version   = 2
    ethernets = { primary = merge(local.nic_pieces...) }
  }

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

  user_data = join("\n", ["#cloud-config", yamlencode({
    hostname         = var.hostname
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
}

# A guest payload with nothing to test is a misconfiguration, not a run.
check "suite_not_empty" {
  assert {
    condition     = length(local.check_keys) > 0
    error_message = "The check suite is empty: checks_file/checks must define at least one can_i_reach_* list (e.g. can_i_reach_endpoints)."
  }
}
