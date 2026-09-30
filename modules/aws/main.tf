locals {
  hostname = var.hostname != "" ? var.hostname : var.vm_name
  tags = merge(
    { Name = var.vm_name, "can-i-reach" = "preflight" },
    var.tags,
  )
}

module "cloud_init" {
  source = "../cloud-init"

  hostname       = local.hostname
  ssh_user       = var.ssh_user
  ssh_public_key = var.ssh_public_key

  # The VPC assigns addressing; the guest keeps DHCP.

  checks_file = var.checks_file
  checks      = var.checks
  fail_on     = var.fail_on
  report_path = var.report_path

  install_tooling      = var.install_tooling
  ansible_core_version = var.ansible_core_version
  collection_source    = var.collection_source
  pip_index_url        = var.pip_index_url

  proxy_url        = var.proxy_url
  no_proxy         = var.no_proxy
  proxy_for_checks = var.proxy_for_checks
}

data "aws_subnet" "this" {
  id = var.subnet_id
}

data "aws_ssm_parameter" "ami" {
  count = var.ami == "" ? 1 : 0
  name  = var.ami_ssm_parameter
}

resource "aws_security_group" "this" {
  count       = length(var.security_group_ids) == 0 ? 1 : 0
  name_prefix = "${var.vm_name}-"
  description = "can-i-reach preflight: SSH in, everything out (the suite decides what is reachable)"
  vpc_id      = data.aws_subnet.this.vpc_id
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = length(var.security_group_ids) == 0 ? toset(var.ssh_ingress_cidrs) : toset([])
  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  tags              = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count             = length(var.security_group_ids) == 0 ? 1 : 0
  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  tags              = local.tags
}

resource "aws_instance" "this" {
  ami                         = var.ami != "" ? var.ami : data.aws_ssm_parameter.ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ip != "" ? var.private_ip : null
  associate_public_ip_address = var.associate_public_ip
  vpc_security_group_ids      = length(var.security_group_ids) > 0 ? var.security_group_ids : [aws_security_group.this[0].id]
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  user_data                   = module.cloud_init.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = local.tags
}

locals {
  vm_ip = var.associate_public_ip ? aws_instance.this.public_ip : aws_instance.this.private_ip
}

module "verdict" {
  source = "../verdict"

  enabled                = var.wait_for_result
  host                   = local.vm_ip
  instance_id            = aws_instance.this.id
  suite_hash             = module.cloud_init.suite_hash
  ssh_user               = var.ssh_user
  ssh_port               = var.ssh_port
  ssh_private_key        = var.ssh_private_key
  result_timeout_seconds = var.result_timeout_seconds
}
