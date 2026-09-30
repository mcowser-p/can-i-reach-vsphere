# vSphere-specific inputs. The common inputs live in common.tf.

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
  description = "Name (or inventory path) of the cloud-init enabled template to clone."
  type        = string
}

# --- Virtual machine --------------------------------------------------------

variable "num_cpus" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
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
# vSphere hands the guest its addressing through cloud-init; clouds
# with their own IPAM do not need these.

variable "ipv4_address" {
  description = "Static IPv4 address in CIDR form (e.g. 10.40.1.50/24). Empty = DHCP."
  type        = string
  default     = ""
}

variable "ipv4_gateway" {
  description = "Default gateway for the static address. Leave empty on a VLAN with no router."
  type        = string
  default     = ""
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "dns_search" {
  type    = list(string)
  default = []
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
