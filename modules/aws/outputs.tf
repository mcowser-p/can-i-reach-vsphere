output "vm_id" {
  description = "Instance id of the test VM."
  value       = aws_instance.this.id
}

output "vm_name" {
  value = var.vm_name
}

output "vm_ip" {
  description = "Address the verdict was (or can be) read from."
  value       = local.vm_ip
}

output "report_path" {
  value = var.report_path
}

output "checks" {
  description = "The merged suite as written into the guest."
  value       = module.cloud_init.checks
}

output "cloud_init_userdata" {
  value = module.cloud_init.user_data
}

output "console_command" {
  description = "Reads the boot log without SSH (the guest prints its verdict line to the console)."
  value       = "aws ec2 get-console-output --instance-id ${aws_instance.this.id} --output text | grep -E 'can-i-reach: (verdict|boot-time)'"
}

output "verdict_enabled" {
  value = module.verdict.enabled
}
