data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

# Same shape as the hand-built cluster: Free tier, one node, system-assigned
# identity, Azure CNI overlay, standard load balancer. Nothing else is enabled
# (no monitoring add-on, no Log Analytics workspace, no extra node pools).
resource "azurerm_kubernetes_cluster" "lab" {
  name                = var.cluster_name
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  dns_prefix          = var.cluster_name
  sku_tier            = "Free"

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
  }

  tags = {
    project = "cloud-lab"
    ticket  = "CLOUD-44"
  }
}
