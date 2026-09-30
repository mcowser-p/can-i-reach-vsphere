# can-i-reach-vsphere 📡🧪

An OpenTofu module that answers one question about a VLAN: **can a VM
placed on it reach what it is supposed to reach?** It clones a template
onto the port group, hands the guest a YAML list of network resources,
and runs [can-i-reach](https://github.com/mcowser-p/can-i-reach) *from
inside the VM* — real TCP connects, real UDP datagrams, real HTTPS
requests, real ICMP — then fails `tofu apply` if anything is unreachable.
`tofu destroy` removes the VM again.

The vantage point is the whole point: firewalls, VLAN ACLs, routing and
DNS are judged from where the workload will actually live, not from the
runner.

```text
tofu apply
  └─ vsphere_virtual_machine        clone template → port group (the VLAN)
       guestinfo.metadata           hostname + static IP / DHCP
       guestinfo.userdata           #cloud-config: user, suite, scripts
            └─ first boot
                 can-i-reach-install   python3, ansible-core, the collection
                 can-i-reach-run       ansible-playbook … can_i_reach
                                       → /var/log/can-i-reach.log
                                       → /var/lib/can-i-reach/{exit-code,report.yml}
                                       → guestinfo.can_i_reach.{verdict,exit_code,report}
  └─ terraform_data.verdict (ssh)   waits, replays the log, exits with the verdict
```

## Quick start

```hcl
module "preflight" {
  source = "git::https://github.com/mcowser-p/can-i-reach-vsphere.git?ref=v1"

  datacenter = "DC1"
  cluster    = "Cluster-A"
  datastore  = "vsan-ds"
  template   = "ubuntu-24.04-cloudinit"
  network    = "VLAN-40-App"          # the port group under test

  ipv4_address = "10.40.1.250/24"     # or "" for DHCP
  ipv4_gateway = "10.40.1.1"
  dns_servers  = ["10.40.0.10"]

  ssh_public_key = file("~/.ssh/id_ed25519.pub")
  checks_file    = "${path.root}/checks.yml"
}
```

```yaml
# checks.yml — every key is a can-i-reach variable
can_i_reach_endpoints:
  - {name: gateway,    host: 10.40.1.1,        protocol: icmp}
  - {name: sql,        host: 10.40.2.11,       port: 1433}                     # tcp
  - {name: syslog,     host: 10.40.0.20,       port: 514,  protocol: udp}
  - {name: ntp,        host: 10.40.0.10,       port: 123,  protocol: udp, expect_reply: true}
  - {name: api-health, host: api.corp.example, port: 443,  path: /healthz, status_codes: [200]}
can_i_reach_dns_servers: [10.40.0.10, 10.40.0.11]
can_i_reach_dns_queries:
  - {name: api.corp.example, expected_values: [10.40.3.20]}
can_i_reach_repo_enabled: false
```

```bash
tofu init && tofu apply      # fails when a check fails; the report is in the output
tofu destroy                 # the VM is disposable
```

[`examples/basic`](examples/basic) is a complete root module with a
provider block, a `terraform.tfvars.example`, and a `make preflight`
target that applies, always destroys, and exits with the verdict.

## The suite file

`checks_file` is plain can-i-reach configuration — a YAML mapping of
`can_i_reach_*` variables — so anything the collection can test, this
module can test on a VLAN: endpoints (tcp / udp / icmp / http(s)), DNS
against specific servers, domain-controller port sweeps, NTP, proxies,
package repositories. The full catalog is documented in
[can-i-reach's defaults](https://github.com/mcowser-p/can-i-reach/blob/main/roles/can_i_reach/defaults/main.yml).

`checks` (an inline map) is merged over the file per key, and the module
sets two keys itself: `can_i_reach_fail_on` from `fail_on`
(`fail` | `warn` | `never`) and `can_i_reach_report_path`.

Two semantics worth knowing before reading a report:

- **UDP is honest.** A datagram can prove *answered*, *closed* (ICMP
  port-unreachable) or *silence* — and silence is `warn`, not `ok`,
  unless the entry sets `expect_reply: true` (then silence is `fail`).
  Test DNS and NTP by protocol (`can_i_reach_dns_queries`,
  `can_i_reach_time_sources`) rather than by blind datagram.
- **The apt/dnf refresh is on by default** in can-i-reach because it is a
  real reachability test. Disable it (`can_i_reach_repo_enabled: false`)
  when the VLAN is not meant to reach repositories.

## Reading the verdict

**Default — over SSH** (`wait_for_result = true`): the runner connects
to the VM as `ssh_user`, waits for the boot-time run to finish, prints
the full log into the apply output, and `tofu apply` exits non-zero when
the suite failed. The VM stays up for inspection; destroy it when done.

**Without SSH** (`wait_for_result = false`, for runners that cannot reach
the VLAN): the guest publishes the verdict through VMware Tools, readable
from vCenter with [govc](https://github.com/vmware/govmomi/tree/main/govc):

```bash
govc vm.info -e -json can-i-reach-preflight \
  | jq -r '.virtualMachines[0].config.extraConfig[]
           | select(.key | startswith("guestinfo.can_i_reach.")) | "\(.key)=\(.value)"'
# guestinfo.can_i_reach.verdict=fail
# guestinfo.can_i_reach.exit_code=2
# guestinfo.can_i_reach.report=<base64 YAML>
```

The `guestinfo_command` output prints exactly that command for the VM.

## Template requirements

- **cloud-init with the VMware datasource** and **open-vm-tools**. Ubuntu
  cloud images (22.04+) work as they are; they read `guestinfo.metadata`
  / `guestinfo.userdata` on first boot. The interface is matched by name
  (`e*`) or, when `mac_address` is set, by MAC — set a MAC on
  EL-family images if name matching is unreliable there.
- **Egress to your package mirror, PyPI and GitHub/Galaxy**, or a
  pre-baked template. `install_tooling = true` (default) installs
  `python3`, `git`, `ansible-core` (`ansible_core_version`) and the
  collection (`collection_source`) on first boot; `pip_index_url` points
  pip at a mirror. On an isolated VLAN — often the very thing being
  tested — bake those into the template and set `install_tooling = false`.
  The runner then looks for `/opt/can-i-reach/venv/bin/ansible-playbook`
  and falls back to `ansible-playbook` on `PATH`, and for the collection
  under `/opt/can-i-reach/collections` and then the default paths.

## Inputs

Every input is documented in [`variables.tf`](variables.tf). The
required ones are `datacenter`, `cluster`, `datastore`, `template`,
`network`, `ssh_public_key`, and a suite via `checks_file` and/or
`checks`. Placement (`resource_pool`, `folder`), sizing (`num_cpus`,
`memory_mb`, `disk_size_gb`, `firmware`), guest networking
(`ipv4_address`, `ipv4_gateway`, `dns_servers`, `dns_search`,
`mac_address`), tooling and verdict behaviour all have defaults.

Outputs: `vm_id`, `vm_name`, `vm_ip`, `report_path`, `checks` (the
merged suite), `guestinfo_command`, and the rendered `cloud_init_userdata`
/ `cloud_init_metadata` for inspection.

## Testing

`tofu test` runs plan-only tests against a **mocked** vSphere provider
([`tests/plan.tftest.hcl`](tests/plan.tftest.hcl)) — no vCenter needed —
covering DHCP and static addressing, MAC matching, suite merging, the
install/verdict switches and the empty-suite guard. CI adds `tofu fmt`,
`tofu validate` (module and example), yamllint, shellcheck on the guest
scripts, and tflint.

An end-to-end run needs a real vCenter: `cp examples/basic/terraform.tfvars.example
examples/basic/terraform.tfvars`, fill it in, `make -C examples/basic preflight`.

## Releasing

semantic-release on `main` with the angular preset (scoped conventional
commits; `chore` never releases). Tags are `vX.Y.Z` and the floating
major tag (`v1`) follows each release, so `?ref=v1` tracks the latest
compatible version.

## License

Apache-2.0
