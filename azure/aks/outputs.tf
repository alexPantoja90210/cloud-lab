output "kubernetes_version" {
  value = azurerm_kubernetes_cluster.lab.kubernetes_version
}

output "sku_tier" {
  value = azurerm_kubernetes_cluster.lab.sku_tier
}

output "node_count" {
  value = azurerm_kubernetes_cluster.lab.default_node_pool[0].node_count
}
