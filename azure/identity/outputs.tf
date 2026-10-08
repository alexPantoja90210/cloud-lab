output "identity_name" {
  description = "Name of the managed identity that layer 1 resources attach to."
  value       = azurerm_user_assigned_identity.reader.name
}

output "role_name" {
  value = azurerm_role_definition.blob_reader.name
}
