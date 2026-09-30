variable "vsphere_server" {
  type = string
}

variable "vsphere_user" {
  type = string
}

variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "vsphere_allow_unverified_ssl" {
  type    = bool
  default = false
}

variable "datacenter" {
  type = string
}

variable "cluster" {
  type = string
}

variable "datastore" {
  type = string
}

variable "folder" {
  type    = string
  default = ""
}

variable "template" {
  type = string
}

variable "network" {
  description = "Port group name of the VLAN under test."
  type        = string
}

variable "vm_name" {
  type    = string
  default = "can-i-reach-preflight"
}

variable "ipv4_address" {
  description = "CIDR, or empty for DHCP."
  type        = string
  default     = ""
}

variable "ipv4_gateway" {
  type    = string
  default = ""
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_private_key" {
  description = "Empty = use the SSH agent."
  type        = string
  default     = ""
  sensitive   = true
}
