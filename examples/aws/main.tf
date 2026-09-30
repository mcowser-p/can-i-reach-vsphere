# Same suite, same inputs, different platform: one throwaway EC2 instance
# in the subnet under test. The runner needs SSH to the instance's
# private address (VPN / bastion / same VPC) — or set associate_public_ip.

provider "aws" {
  region = var.region
}

module "preflight" {
  source = "../../modules/aws"
  # From a release instead:
  # source = "git::https://github.com/mcowser-p/can-my-server-reach.git//modules/aws?ref=v2"

  subnet_id         = var.subnet_id # the network under test
  instance_type     = "t3.small"
  ssh_ingress_cidrs = var.ssh_ingress_cidrs

  vm_name         = var.vm_name
  ssh_public_key  = var.ssh_public_key
  ssh_private_key = var.ssh_private_key

  checks_file = "${path.root}/checks.yml"
  fail_on     = "fail"

  tags = { Environment = "preflight" }
}

output "vm_ip" {
  value = module.preflight.vm_ip
}

output "read_verdict_without_ssh" {
  value = module.preflight.console_command
}
