output "user_data" {
  description = "The rendered #cloud-config."
  value       = local.user_data
}

output "network_config" {
  description = "cloud-init network config v2 as an object, for platforms that hand the guest its network (vSphere guestinfo). Cloud platforms that assign addresses themselves ignore it."
  value       = local.network_config
}

output "checks" {
  description = "The merged suite as written to /etc/can-i-reach/checks.yml in the guest."
  value       = local.checks
}

output "check_keys" {
  description = "The can_i_reach_* keys in the suite that describe something to test."
  value       = local.check_keys
}

output "suite_hash" {
  description = "Short hash of the merged suite; platforms fold it into the instance-id so a changed suite re-runs cloud-init."
  value       = local.suite_hash
}

output "static_ip" {
  description = "The static address without prefix, or null under DHCP."
  value       = local.static_ip ? split("/", var.ipv4_address)[0] : null
}
