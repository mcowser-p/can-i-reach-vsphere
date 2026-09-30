variable "enabled" {
  description = "false = do not connect; read the verdict some other way (vSphere guestinfo, console, the report file)."
  type        = bool
  default     = true
}

variable "host" {
  description = "Address to SSH to. Null is tolerated while enabled=false."
  type        = string
  nullable    = true
}

variable "instance_id" {
  description = "Platform id of the VM; a new VM re-runs the step."
  type        = string
}

variable "suite_hash" {
  description = "Hash of the suite; a changed suite re-runs the step."
  type        = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_port" {
  type    = number
  default = 22
}

variable "ssh_private_key" {
  description = "Empty = use the SSH agent."
  type        = string
  default     = ""
  sensitive   = true
}

variable "connect_timeout" {
  description = "How long to keep trying to open the SSH connection."
  type        = string
  default     = "10m"
}

variable "result_timeout_seconds" {
  description = "How long the guest-side wait script waits for the boot-time run to finish."
  type        = number
  default     = 1200
}
