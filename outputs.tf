output "vm_id" {
  description = "Managed object ID of the test VM."
  value       = vsphere_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the test VM."
  value       = vsphere_virtual_machine.this.name
}

output "vm_ip" {
  description = "Address the verdict was (or can be) read from."
  value       = local.vm_ip
}

output "report_path" {
  description = "Where the YAML report lives inside the guest."
  value       = var.report_path
}

output "guestinfo_command" {
  description = "Reads the verdict without SSH (govc), for runners that cannot reach the VLAN."
  value       = "govc vm.info -e -json '${var.vm_name}' | jq -r '.virtualMachines[0].config.extraConfig[] | select(.key | startswith(\"guestinfo.can_i_reach.\")) | \"\\(.key)=\\(.value)\"'"
}

output "cloud_init_userdata" {
  description = "The rendered #cloud-config, for inspection and tests."
  value       = local.userdata
}

output "cloud_init_metadata" {
  description = "The rendered cloud-init metadata (hostname + network), for inspection and tests."
  value       = local.metadata
}

output "checks" {
  description = "The merged suite as written to /etc/can-i-reach/checks.yml in the guest."
  value       = local.checks
}
