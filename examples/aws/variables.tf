variable "region" {
  type = string
}

variable "subnet_id" {
  description = "Subnet under test."
  type        = string
}

variable "ssh_ingress_cidrs" {
  description = "Where the runner connects from."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "vm_name" {
  type    = string
  default = "can-i-reach-preflight"
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
