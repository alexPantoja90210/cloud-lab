# Names only. Copy them into azure/layer1/backend.local.hcl (gitignored).
output "backend_config" {
  description = "Contents for azure/layer1/backend.local.hcl"
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "layer1.tfstate"
    use_azuread_auth     = true
  EOT
}
