# Layer 0: identity definitions. Free, and never part of a teardown.
# This root has its own state (key identity.tfstate); azure/layer1 cannot reach it.

data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

locals {
  tags = {
    lab   = "cloud-lab"
    layer = "0"
  }
}

# Custom role scoped to ONE resource group: can read storage account metadata and READ blobs.
# Deliberately has no write data action and no listKeys, so keys are never an option.
resource "azurerm_role_definition" "blob_reader" {
  name        = "lab-blob-reader"
  scope       = data.azurerm_resource_group.lab.id
  description = "Cloud lab: read blobs in one resource group. No writes, no account keys."

  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/read",
    ]
    # Listing and reading blobs is one data action. "containers/read" is a control-plane
    # action, not a data action, and Azure rejects it here (found by apply, not by validate).
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    ]
    not_actions      = []
    not_data_actions = []
  }

  assignable_scopes = [
    data.azurerm_resource_group.lab.id,
  ]

  lifecycle {
    prevent_destroy = true
  }
}

# Layer 0 identities live in their own group so that rg-cloud-lab (the layer 1 container)
# stays empty between sessions and "is it empty?" keeps meaning something.
resource "azurerm_resource_group" "identity" {
  name     = "rg-cloud-lab-identity"
  location = data.azurerm_resource_group.lab.location
  tags     = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Managed identity: the thing a resource uses instead of a key.
resource "azurerm_user_assigned_identity" "reader" {
  name                = "id-cloud-lab-reader"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_role_assignment" "reader" {
  scope              = data.azurerm_resource_group.lab.id
  role_definition_id = azurerm_role_definition.blob_reader.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.reader.principal_id
  principal_type     = "ServicePrincipal"
}
