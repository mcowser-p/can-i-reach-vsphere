# --- Placement --------------------------------------------------------------

variable "datacenter" {
  description = "Name of the vSphere datacenter."
  type        = string
}

variable "cluster" {
  description = "Name of the compute cluster the VM is placed in."
  type        = string
}

variable "resource_pool" {
  description = "Resource pool inside the cluster. Empty = the cluster's root pool."
  type        = string
  default     = ""
}

variable "datastore" {
  description = "Datastore for the VM's disk."
  type        = string
}

variable "folder" {
  description = "VM folder path (relative to the datacenter). Empty = datacenter root."
  type        = string
  default     = ""
}

variable "network" {
  description = "Name of the port group (the VLAN) to attach the VM to. This is the network under test."
  type        = string
}

variable "template" {
  description = "Name (or inventory path) of the cloud-init enabled template to clone. Ubuntu cloud images work out of the box."
  type        = string
}

# --- Virtual machine --------------------------------------------------------

variable "vm_name" {
  description = "Name of the test VM in vCenter."
  type        = string
  default     = "can-i-reach-preflight"
}

variable "hostname" {
  description = "Guest hostname. Empty = vm_name."
  type        = string
  default     = ""
}

variable "num_cpus" {
  description = "vCPU count."
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "Memory in MiB."
  type        = number
  default     = 2048
}

variable "disk_size_gb" {
  description = "Disk size in GiB. null = keep the template's size."
  type        = number
  default     = null
}

variable "firmware" {
  description = "bios | efi. Empty = whatever the template reports."
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "bios", "efi"], var.firmware)
    error_message = "firmware must be empty, bios or efi."
  }
}

variable "annotation" {
  description = "Notes field on the VM."
  type        = string
  default     = "can-i-reach network preflight — safe to delete"
}

# --- Guest network ----------------------------------------------------------

variable "ipv4_address" {
  description = "Static IPv4 address in CIDR form (e.g. 10.40.1.50/24). Empty = DHCP."
  type        = string
  default     = ""

  validation {
    condition     = var.ipv4_address == "" || can(cidrhost(var.ipv4_address, 0))
    error_message = "ipv4_address must be empty (DHCP) or an address in CIDR form, e.g. 10.40.1.50/24."
  }
}

variable "ipv4_gateway" {
  description = "Default gateway for the static address. Leave empty on a VLAN with no router if you only test on-link targets."
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "DNS servers pushed to the guest with a static address."
  type        = list(string)
  default     = []
}

variable "dns_search" {
  description = "DNS search domains pushed to the guest with a static address."
  type        = list(string)
  default     = []
}

variable "mac_address" {
  description = "Fixed MAC for the NIC. Empty = vSphere assigns one and the guest matches the interface by name (e*)."
  type        = string
  default     = ""
}

variable "guest_ip_timeout" {
  description = "Minutes to wait for VMware Tools to report a guest IP after power-on."
  type        = number
  default     = 5
}

# --- SSH access (used to read the verdict back) ------------------------------

variable "ssh_user" {
  description = "User created in the guest by cloud-init, with passwordless sudo."
  type        = string
  default     = "preflight"
}

variable "ssh_public_key" {
  description = "Public key authorised for ssh_user."
  type        = string
}

variable "ssh_private_key" {
  description = "Matching private key, used by the remote-exec step. Empty = use the SSH agent."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH port in the guest."
  type        = number
  default     = 22
}

# --- The check suite --------------------------------------------------------

variable "checks_file" {
  description = "Path to a YAML file of can-i-reach variables (can_i_reach_endpoints, can_i_reach_dns_queries, ...). Empty = only `checks` is used."
  type        = string
  default     = ""

  validation {
    condition     = var.checks_file == "" || fileexists(var.checks_file)
    error_message = "checks_file does not exist. Use an absolute path or \"${path.root}/checks.yml\"."
  }
}

variable "checks" {
  description = "Inline can-i-reach variables, merged over checks_file (inline wins per key)."
  type        = any
  default     = {}
}

variable "fail_on" {
  description = "When the suite counts as failed: fail | warn | never. `never` turns the run into a pure report."
  type        = string
  default     = "fail"

  validation {
    condition     = contains(["fail", "warn", "never"], var.fail_on)
    error_message = "fail_on must be one of: fail, warn, never."
  }
}

variable "report_path" {
  description = "Where the YAML report is written inside the guest."
  type        = string
  default     = "/var/lib/can-i-reach/report.yml"
}

# --- Tooling on the guest ---------------------------------------------------

variable "install_tooling" {
  description = "Install python3/venv/git, ansible-core and the collection on first boot. Set false when the template is pre-baked (e.g. the VLAN has no egress)."
  type        = bool
  default     = true
}

variable "ansible_core_version" {
  description = "ansible-core version pip-installed on the guest."
  type        = string
  default     = "2.21.4"
}

variable "collection_source" {
  description = "What ansible-galaxy installs: a Galaxy name, a tarball URL, or a git+https URL (optionally ,ref)."
  type        = string
  default     = "git+https://github.com/mcowser-p/can-i-reach.git"
}

variable "pip_index_url" {
  description = "Internal PyPI mirror for the guest. Empty = pypi.org."
  type        = string
  default     = ""
}

# --- Reading the verdict back -----------------------------------------------

variable "wait_for_result" {
  description = "SSH into the guest after boot, wait for the run to finish, replay its log and fail the apply when the suite failed. Set false when the runner cannot reach the VLAN; read guestinfo instead."
  type        = bool
  default     = true
}

variable "result_timeout_seconds" {
  description = "How long the remote-exec step waits for the boot-time run to finish."
  type        = number
  default     = 1200
}
