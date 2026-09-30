output "vm_id" {
  description = "Managed object ID of the test VM."
  value       = vsphere_virtual_machine.this.id
}

output "vm_name" {
  value = vsphere_virtual_machine.this.name
}

output "vm_ip" {
  description = "Address the verdict was (or can be) read from."
  value       = local.vm_ip
}

output "report_path" {
  value = var.report_path
}

output "guestinfo_command" {
  description = "Reads the verdict without SSH (govc), for runners that cannot reach the VLAN."
  value       = "govc vm.info -e -json '${var.vm_name}' | jq -r '.virtualMachines[0].config.extraConfig[] | select(.key | startswith(\"guestinfo.can_i_reach.\")) | \"\\(.key)=\\(.value)\"'"
}

output "checks" {
  description = "The merged suite as written into the guest."
  value       = module.cloud_init.checks
}

output "cloud_init_userdata" {
  value = module.cloud_init.user_data
}

output "cloud_init_metadata" {
  value = local.metadata
}

output "verdict_enabled" {
  value = module.verdict.enabled
}
