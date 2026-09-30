# The guest payload, independent of where the VM runs. Platform modules
# expose these same inputs (see modules/*/common.tf) and pass them here.

variable "hostname" {
  description = "Guest hostname."
  type        = string
}

# --- SSH access -------------------------------------------------------------

variable "ssh_user" {
  description = "User created in the guest by cloud-init, with passwordless sudo."
  type        = string
  default     = "preflight"
}

variable "ssh_public_key" {
  description = "Public key authorised for ssh_user."
  type        = string
}

# --- Guest network (rendered as cloud-init network config v2) ---------------

variable "ipv4_address" {
  description = "Static IPv4 address in CIDR form. Empty = DHCP."
  type        = string
  default     = ""

  validation {
    condition     = var.ipv4_address == "" || can(cidrhost(var.ipv4_address, 0))
    error_message = "ipv4_address must be empty (DHCP) or an address in CIDR form, e.g. 10.40.1.50/24."
  }
}

variable "ipv4_gateway" {
  description = "Default gateway for the static address."
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "DNS servers pushed with a static address."
  type        = list(string)
  default     = []
}

variable "dns_search" {
  description = "DNS search domains pushed with a static address."
  type        = list(string)
  default     = []
}

variable "mac_address" {
  description = "Match the interface by this MAC instead of by name (e*)."
  type        = string
  default     = ""
}

# --- The check suite --------------------------------------------------------

variable "checks_file" {
  description = "Path to a YAML file of can-i-reach variables. Empty = only `checks` is used."
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
  description = "When the suite counts as failed: fail | warn | never."
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
  description = "Install python3/venv/git, ansible-core and the collection on first boot. false = pre-baked image."
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

# --- Proxy --------------------------------------------------------------------

variable "proxy_url" {
  description = "HTTP proxy for the guest (tooling install and, with proxy_for_checks, the suite's default proxy)."
  type        = string
  default     = ""
}

variable "no_proxy" {
  description = "Hosts/domains that bypass proxy_url."
  type        = list(string)
  default     = []
}

variable "proxy_for_checks" {
  description = "Inject proxy_url as can_i_reach_proxy unless the suite sets it itself."
  type        = bool
  default     = true
}
