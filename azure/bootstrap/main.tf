locals {
  tags_layer0 = {
    lab    = "cloud-lab"
    layer  = "0"
    domain = "foundation"
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Layer 0: the empty container that layer 1 deploys into.
# prevent_destroy makes an accidental destroy of this root fail loudly.
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags_layer0

  lifecycle {
    prevent_destroy = true
  }
}

# Layer 0: state backend, in its own resource group so it can never share a fate with the lab group.
resource "azurerm_resource_group" "state" {
  name     = "rg-cloud-lab-state"
  location = var.location
  tags     = local.tags_layer0

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "state" {
  name                     = "stcloudlab${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # No account keys: the backend authenticates with Entra ID only.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }

  tags = local.tags_layer0

  lifecycle {
    prevent_destroy = true
  }
}

# The operator needs data-plane rights because key access is disabled.
resource "azurerm_role_assignment" "operator_blob" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role assignments take time to propagate; creating the container immediately can return 403.
resource "time_sleep" "rbac_propagation" {
  depends_on      = [azurerm_role_assignment.operator_blob]
  create_duration = "90s"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  depends_on = [time_sleep.rbac_propagation]
}
