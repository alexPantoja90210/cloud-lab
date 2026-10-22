output "app_fqdn" {
  value = azurerm_container_app.hello.ingress[0].fqdn
}

output "min_replicas" {
  value = azurerm_container_app.hello.template[0].min_replicas
}
