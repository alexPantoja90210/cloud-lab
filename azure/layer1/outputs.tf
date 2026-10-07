output "target_resource_group" {
  description = "The layer 1 container."
  value       = data.azurerm_resource_group.lab.name
}
