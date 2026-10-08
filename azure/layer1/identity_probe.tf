# CLOUD-24 identity probe (layer 1, destroyed after every session).
# A container with a managed identity (no key, no secret) tries two things on a storage
# account that has shared keys disabled: a read the role allows, and a write it does not.
# The captured denial is the deliverable, not the role.

data "azurerm_client_config" "current" {}

data "azurerm_user_assigned_identity" "reader" {
  name                = var.identity_name
  resource_group_name = var.identity_resource_group_name
}

resource "random_string" "probe_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "probe_target" {
  name                     = "stlabprobe${random_string.probe_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.lab.name
  location                 = data.azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Identity only: account keys are switched off, so the probe cannot cheat with a key.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  tags = local.tags
}

# The operator needs data-plane rights to create the container and blob (keys are off).
resource "azurerm_role_assignment" "operator_blob" {
  scope                = azurerm_storage_account.probe_target.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "rbac_propagation" {
  depends_on      = [azurerm_role_assignment.operator_blob]
  create_duration = "90s"
}

resource "azurerm_storage_container" "probe" {
  name                  = "probe"
  storage_account_id    = azurerm_storage_account.probe_target.id
  container_access_type = "private"

  depends_on = [time_sleep.rbac_propagation]
}

resource "azurerm_storage_blob" "hello" {
  name                   = "hello.txt"
  storage_account_name   = azurerm_storage_account.probe_target.name
  storage_container_name = azurerm_storage_container.probe.name
  type                   = "Block"
  source_content         = "hello from the cloud lab"
}

locals {
  probe_script = <<-EOT
    set -u
    echo "== probe start (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    az login --identity --client-id "${data.azurerm_user_assigned_identity.reader.client_id}" --output none
    echo "== 1. READ, allowed by the role:"
    az storage blob list --account-name "${azurerm_storage_account.probe_target.name}" --container-name probe --auth-mode login --query "[].name" --output tsv
    echo "== 2. WRITE, not allowed by the role (expect a denial):"
    echo "should not be written" > /tmp/denied.txt
    az storage blob upload --account-name "${azurerm_storage_account.probe_target.name}" --container-name probe --name denied.txt --file /tmp/denied.txt --auth-mode login --output none
    echo "== write exit code: $?"
    echo "== probe end (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  EOT
}

resource "azurerm_container_group" "probe" {
  name                = "aci-identity-probe"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  os_type             = "Linux"
  restart_policy      = "Never"

  # No network endpoint at all: the probe only makes outbound calls, and a public IP
  # would need an exposed port. "None" avoids both.
  ip_address_type = "None"

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.reader.id]
  }

  container {
    name   = "probe"
    image  = "mcr.microsoft.com/azure-cli:2.91.0"
    cpu    = "0.5"
    memory = "0.5"

    commands = ["/bin/sh", "-c", local.probe_script]
  }

  tags = local.tags

  depends_on = [azurerm_storage_blob.hello]
}
