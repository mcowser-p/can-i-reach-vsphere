# Plan-only tests against a mocked AWS provider: no account needed.
mock_provider "aws" {
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
}

variables {
  subnet_id      = "subnet-0123456789abcdef0"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEY test@example"
  checks = {
    can_i_reach_endpoints = [{ name = "sql", host = "10.40.2.11", port = 1433 }]
  }
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_instance.this.subnet_id == "subnet-0123456789abcdef0"
    error_message = "the instance must launch into the subnet under test"
  }

  assert {
    condition     = aws_instance.this.ami == "ami-0123456789abcdef0"
    error_message = "with no ami given, the SSM parameter resolves it"
  }

  assert {
    condition     = length(aws_security_group.this) == 1 && length(aws_vpc_security_group_ingress_rule.ssh) == 1
    error_message = "with no security groups given, one is created with an SSH rule per ingress cidr"
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address == false
    error_message = "no public address by default"
  }

  assert {
    condition     = startswith(aws_instance.this.user_data, "#cloud-config\n")
    error_message = "user_data is the rendered cloud-config"
  }

  assert {
    condition     = output.checks.can_i_reach_endpoints[0].name == "sql"
    error_message = "the suite must reach the guest"
  }

  assert {
    condition     = output.verdict_enabled
    error_message = "wait_for_result defaults to true"
  }
}

run "bring_your_own" {
  command = plan

  variables {
    ami                = "ami-custom"
    security_group_ids = ["sg-1", "sg-2"]
    private_ip         = "10.40.2.250"
    wait_for_result    = false
  }

  assert {
    condition     = aws_instance.this.ami == "ami-custom"
    error_message = "an explicit ami wins"
  }

  assert {
    condition     = length(aws_security_group.this) == 0 && length(data.aws_ssm_parameter.ami) == 0
    error_message = "existing security groups and an explicit ami skip the created ones"
  }

  assert {
    condition     = aws_instance.this.private_ip == "10.40.2.250"
    error_message = "a fixed private ip is passed through"
  }

  assert {
    condition     = !output.verdict_enabled
    error_message = "wait_for_result=false must skip the verdict step"
  }
}
