output "target_resource_group" {
  description = "The layer 1 container."
  value       = data.azurerm_resource_group.lab.name
}

output "probe_storage_account" {
  description = "Storage account the identity probe targets."
  value       = azurerm_storage_account.probe_target.name
}

output "compute_vm_name" {
  description = "VM of the CLOUD-28 compute exercise, for the power-state commands."
  value       = azurerm_linux_virtual_machine.compute.name
}
