# The drop-in contract: every platform module exposes exactly these
# inputs (CI diffs this file across modules/*/common.tf). Swap a
# platform by changing the module `source`; keep the rest.

# --- Identity ---------------------------------------------------------------

variable "vm_name" {
  description = "Name of the test VM on the platform."
  type        = string
  default     = "can-i-reach-preflight"
}

variable "hostname" {
  description = "Guest hostname. Empty = vm_name."
  type        = string
  default     = ""
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
  description = "Matching private key for the verdict step. Empty = use the SSH agent."
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
  description = "Path to a YAML file of can-i-reach variables. Empty = only `checks` is used."
  type        = string
  default     = ""
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
  description = "HTTP proxy for the guest: the tooling install and, with proxy_for_checks, the suite's default proxy."
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

# --- Reading the verdict back -----------------------------------------------

variable "wait_for_result" {
  description = "SSH into the guest after boot, wait for the run, replay its log and fail the apply on a failed suite. false when the runner cannot reach the guest."
  type        = bool
  default     = true
}

variable "result_timeout_seconds" {
  description = "How long the verdict step waits for the boot-time run to finish."
  type        = number
  default     = 1200
}
