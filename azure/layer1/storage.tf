# CLOUD-26 storage (layer 1, destroyed after every session).
# A storage account with shared keys off, a container, a lifecycle policy, and a private endpoint.
# The deliberate failures are captured by hand, not created here:
#   1. a user-delegation SAS seen to expire (phase 1, public network access on),
#   2. a direct public read refused (phase 2, private_only = true).
#
# The blob itself is uploaded with the CLI during the session, not by Terraform, so nothing here
# needs the data plane. The lifecycle policy is CONFIGURED and read back from the API; Azure
# takes up to 24 hours to run it, so it is never observed acting inside a session.
# Tags: lab and layer from local.tags; domain is set per resource.

variable "private_only" {
  description = "false: the account accepts public network traffic (phase 1, SAS expiry test). true: only the private endpoint reaches it (phase 2, public read refused)."
  type        = bool
  default     = false
}

resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "storage" {
  name                     = "stlabstore${random_string.storage_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.lab.name
  location                 = data.azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Identity only: account keys are off, so the only signed URL possible is a user-delegation SAS.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  # The phase switch. With this false the data plane answers only through the private endpoint.
  public_network_access_enabled = !var.private_only

  tags = merge(local.tags, { domain = "storage" })
}

# Containers are managed through the management plane (storage_account_id), so this works
# whatever the network setting is.
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

# The operator needs data-plane rights because keys are off, and the delegator role to ask for a
# user delegation key. Role assignments take time to propagate, hence the wait.
resource "azurerm_role_assignment" "storage_operator_blob" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "storage_operator_delegator" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Delegator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "storage_rbac" {
  depends_on = [
    azurerm_role_assignment.storage_operator_blob,
    azurerm_role_assignment.storage_operator_delegator,
  ]
  create_duration = "90s"
}

resource "azurerm_storage_management_policy" "storage" {
  storage_account_id = azurerm_storage_account.storage.id

  rule {
    name    = "tier-down-then-delete"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
    }
  }
}

# Network and subnet are free. The private endpoint bills by the hour, so it only exists in
# phase 2 (private_only = true) and goes away with the rest of layer 1.
resource "azurerm_virtual_network" "storage" {
  name                = "vnet-cloud-lab-storage"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  address_space       = ["10.20.0.0/24"]

  tags = merge(local.tags, { domain = "storage" })
}

resource "azurerm_subnet" "private_endpoint" {
  name                 = "snet-private-endpoint"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.storage.name
  address_prefixes     = ["10.20.0.0/27"]
}

# No private DNS zone: nothing inside the network reads the account in this session, so the
# endpoint proves the private door exists and the public one is shut, not that a client can use it.
resource "azurerm_private_endpoint" "storage" {
  count = var.private_only ? 1 : 0

  name                = "pe-cloud-lab-storage"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-cloud-lab-storage"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = merge(local.tags, { domain = "storage" })
}

output "storage_account" {
  description = "Storage account of the CLOUD-26 session."
  value       = azurerm_storage_account.storage.name
}

output "storage_container" {
  description = "Container that holds the sample blob."
  value       = azurerm_storage_container.data.name
}

output "storage_private_only" {
  description = "Which phase this state is in."
  value       = var.private_only
}
