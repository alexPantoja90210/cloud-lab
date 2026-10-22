data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

# Consumption-only environment. No log_analytics_workspace_id, so no logs
# destination and no Log Analytics charge (same as --logs-destination none).
resource "azurerm_container_app_environment" "lab" {
  name                = var.environment_name
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  tags = {
    project = "cloud-lab"
    ticket  = "CLOUD-44"
  }
}

# Scale to zero: min 0, max 1. External ingress on port 80.
resource "azurerm_container_app" "hello" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.lab.id
  resource_group_name          = data.azurerm_resource_group.lab.name
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "hello"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = {
    project = "cloud-lab"
    ticket  = "CLOUD-44"
  }
}
