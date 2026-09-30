# can-my-server-reach 📡🧪

OpenTofu modules that answer one question about a network segment:
**can a VM placed on it reach what it is supposed to reach — and nothing
it is not?** A module clones or launches a throwaway VM onto the segment,
hands the guest a YAML list of network resources, and runs
[can-i-reach](https://github.com/mcowser-p/can-i-reach) *from inside the
VM* — real TCP connects, real UDP datagrams, real HTTPS requests, real
ICMP, optionally through a proxy, with `expect: unreachable` for what
must be blocked — then fails `tofu apply` if the suite fails.
`tofu destroy` removes the VM again.

The vantage point is the whole point: firewalls, VLAN ACLs, security
groups, routing and DNS are judged from where the workload will actually
live, not from the runner.

## Platforms are drop-in

The guest payload and the verdict are platform-agnostic; only "make a VM
here" differs. Every platform module exposes the **same common inputs**
(`vm_name`, SSH, suite, tooling, proxy, verdict — see
[`modules/vsphere/common.tf`](modules/vsphere/common.tf), which CI keeps
byte-identical across platforms) plus a handful of platform-specific
ones. Switching clouds is changing `source`:

| module | creates | platform inputs | verdict without SSH |
|---|---|---|---|
| [`modules/vsphere`](modules/vsphere) | `vsphere_virtual_machine` cloned from a cloud-init template onto a port group; addressing via guestinfo (static or DHCP) | `datacenter`, `cluster`, `datastore`, `template`, `network`, sizing, `ipv4_address`… | `guestinfo.can_i_reach.*` via govc (`guestinfo_command` output) |
| [`modules/aws`](modules/aws) | `aws_instance` in a subnet, Ubuntu 24.04 AMI by SSM parameter, optional created security group | `subnet_id`, `ami`, `instance_type`, `private_ip`, `security_group_ids`… | console output (`console_command` output) |

```text
modules/
  cloud-init/   render #cloud-config + network config v2 from the common inputs   (no provider)
  verdict/      SSH in, wait for the boot-time run, replay the log, exit with it   (no provider)
  vsphere/      common.tf + vSphere inputs → cloud-init → VM → verdict
  aws/          common.tf + AWS inputs     → cloud-init → VM → verdict
```

### Adding a platform

Copy `modules/vsphere/common.tf` unchanged, add the platform's own
`variables.tf`, create the VM with `module.cloud_init.user_data` as its
user data (and `network_config` if the platform does not do IPAM), then
call `../verdict` with the VM's address and id. Two short modules, one
mocked plan test, done. The CI contract check fails if `common.tf` drifts.

## Quick start

```hcl
module "preflight" {
  source = "git::https://github.com/mcowser-p/can-my-server-reach.git//modules/vsphere?ref=v2"

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

The same on AWS, same suite:

```hcl
module "preflight" {
  source = "git::https://github.com/mcowser-p/can-my-server-reach.git//modules/aws?ref=v2"

  subnet_id      = "subnet-0123456789abcdef0"   # the subnet under test
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
  - {name: no-rdp-dmz, host: 10.60.0.5,        port: 3389, expect: unreachable}   # must be blocked
can_i_reach_dns_servers: [10.40.0.10, 10.40.0.11]
can_i_reach_dns_queries:
  - {name: api.corp.example, expected_values: [10.40.3.20]}
can_i_reach_repo_enabled: false
```

```bash
tofu init && tofu apply      # fails when a check fails; the report is in the output
tofu destroy                 # the VM is disposable
```

[`examples/vsphere`](examples/vsphere) and [`examples/aws`](examples/aws)
are complete root modules with a provider block, a
`terraform.tfvars.example`, and a `make preflight` target that applies,
always destroys, and exits with the verdict.

## The suite file

`checks_file` is plain can-i-reach configuration — a YAML mapping of
`can_i_reach_*` variables — so anything the collection can test, these
modules can test on a segment: endpoints (tcp / udp / icmp / http(s)),
DNS against specific servers, domain-controller port sweeps, NTP,
proxies, package repositories. The full catalog is documented in
[can-i-reach's defaults](https://github.com/mcowser-p/can-i-reach/blob/main/roles/can_i_reach/defaults/main.yml).

`checks` (an inline map) is merged over the file per key, and the module
sets two keys itself: `can_i_reach_fail_on` from `fail_on`
(`fail` | `warn` | `never`) and `can_i_reach_report_path`.

`expect: unreachable` inverts an entry: it passes only when nothing
answers, which is how a segment's *negative* rules (no RDP into the DMZ,
no ping to management) are proven from the inside.

Two semantics worth knowing before reading a report:

- **UDP is honest.** A datagram can prove *answered*, *closed* (ICMP
  port-unreachable) or *silence* — and silence is `warn`, not `ok`,
  unless the entry sets `expect_reply: true` (then silence is `fail`).
  Test DNS and NTP by protocol (`can_i_reach_dns_queries`,
  `can_i_reach_time_sources`) rather than by blind datagram.
- **The apt/dnf refresh is on by default** in can-i-reach because it is a
  real reachability test. Disable it (`can_i_reach_repo_enabled: false`)
  when the segment is not meant to reach repositories.

## Behind a proxy

```hcl
  proxy_url = "http://proxy.corp.example:3128"   # or http://user:pass@…
  no_proxy  = ["10.40.0.0/16", ".corp.example"]
```

`proxy_url` does two things. The first-boot tooling install (apt/dnf,
pip, git) runs with the proxy environment set, so a segment whose only
egress is a proxy can still bootstrap. And unless `proxy_for_checks =
false`, it becomes the suite's `can_i_reach_proxy`: every http(s) check
goes through the proxy, hosts matching `no_proxy` go direct, and an
entry can still opt out with `proxy: false` or pick another proxy by
name or URL. tcp, udp and icmp checks are never proxied — an HTTP proxy
cannot carry them, so those prove the segment's own routing. A suite
that sets `can_i_reach_proxy` itself keeps its value.

## Reading the verdict

**Default — over SSH** (`wait_for_result = true`): the runner connects
to the VM as `ssh_user`, waits for the boot-time run to finish, prints
the full log into the apply output, and `tofu apply` exits non-zero when
the suite failed. The VM stays up for inspection; destroy it when done.
On AWS that means the runner must reach the instance's private address
(VPN, bastion, same VPC) or you set `associate_public_ip = true`.

**Without SSH** (`wait_for_result = false`, for runners that cannot reach
the segment): the guest still writes `/var/log/can-i-reach.log`, the
exit-code file and the YAML report, and prints a
`can-i-reach: verdict=… exit_code=…` line. On vSphere it also publishes
the verdict, exit code and base64 report through VMware Tools as
`guestinfo.can_i_reach.*`; on AWS the line is in the console output.
Each platform module outputs the exact command to read it
(`guestinfo_command` / `console_command`).

## Image requirements

- **cloud-init** with the platform's datasource and, on vSphere,
  **open-vm-tools**. Ubuntu cloud images (22.04+) work as they are on
  both platforms. On vSphere the interface is matched by name (`e*`) or,
  when `mac_address` is set, by MAC — set a MAC on EL-family images if
  name matching is unreliable there.
- **Egress to your package mirror, PyPI and GitHub/Galaxy**, or a
  pre-baked image. `install_tooling = true` (default) installs
  `python3`, `git`, `ansible-core` (`ansible_core_version`) and the
  collection (`collection_source`) on first boot; `pip_index_url` points
  pip at a mirror and `proxy_url` routes it through a proxy. On an
  isolated segment — often the very thing being tested — bake those into
  the image and set `install_tooling = false`. The runner then looks for
  `/opt/can-i-reach/venv/bin/ansible-playbook` and falls back to
  `ansible-playbook` on `PATH`, and for the collection under
  `/opt/can-i-reach/collections` and then the default paths.

## Testing

`tofu test` in each module directory runs plan-only tests:
[`modules/cloud-init/tests`](modules/cloud-init/tests) renders with no
provider at all (DHCP and static addressing, MAC matching, suite merging,
proxy precedence, the empty-suite guard), and the platform modules run
against **mocked** providers — no vCenter, no AWS account. CI adds
`tofu fmt`, `tofu validate` for every module and example, the drop-in
contract diff, yamllint, shellcheck on the guest scripts, and tflint.

An end-to-end run needs a real platform: copy the example's
`terraform.tfvars.example` to `terraform.tfvars`, fill it in, then
`make -C examples/vsphere preflight` (or `examples/aws`).

## Repository settings

Branch protection for `main` is versioned in
[`.github/rulesets/`](.github/rulesets) as GitHub ruleset JSON (no
deletion, no force-push, `lint`, `tofu` and `commit-messages` checks
required). GitHub does not apply it from the file by itself — run
`.github/rulesets/apply.sh` as a repo admin after cloning to a new org
or editing the JSON; it creates or updates the ruleset by name.

## Releasing

semantic-release on `main` with the angular preset (scoped conventional
commits; `chore` never releases). Tags are `vX.Y.Z` and the floating
major tag (`v2`) follows each release, so `?ref=v2` tracks the latest
compatible version.

## License

Apache-2.0
