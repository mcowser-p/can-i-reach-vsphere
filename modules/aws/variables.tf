# AWS-specific inputs. The common inputs live in common.tf.

variable "subnet_id" {
  description = "Subnet to launch into. This is the network under test."
  type        = string
}

variable "ami" {
  description = "AMI id. Empty = resolve ami_ssm_parameter (Ubuntu 24.04 LTS by default)."
  type        = string
  default     = ""
}

variable "ami_ssm_parameter" {
  description = "SSM public parameter that resolves to the AMI when `ami` is empty."
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "private_ip" {
  description = "Fixed private address inside the subnet. Empty = the subnet's DHCP."
  type        = string
  default     = ""
}

variable "associate_public_ip" {
  description = "Give the instance a public address, and read the verdict through it."
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Existing security groups. Empty = create one that allows SSH from ssh_ingress_cidrs and all egress."
  type        = list(string)
  default     = []
}

variable "ssh_ingress_cidrs" {
  description = "Who may SSH in when the module creates the security group."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "iam_instance_profile" {
  description = "Instance profile name, if the guest needs AWS API access (e.g. an internal mirror behind IAM auth)."
  type        = string
  default     = ""
}

variable "root_volume_gb" {
  type    = number
  default = 10
}

variable "tags" {
  description = "Extra tags on every resource."
  type        = map(string)
  default     = {}
}
