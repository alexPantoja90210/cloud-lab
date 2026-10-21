# DRAFT, not yet validated or applied (CLOUD-36). Twin of the hand-built run.
# One Entra group, one storage account and one container per department.
# Access is granted to the group at container scope, never to a person.

data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azuread_group" "dept" {
  for_each         = var.departments
  display_name     = "${var.group_prefix}-${each.key}"
  mail_nickname    = "${var.group_prefix}-${each.key}"
  security_enabled = true
}

resource "azuread_group_member" "member" {
  for_each = {
    for pair in flatten([
      for dept, ids in var.members : [for id in ids : { key = "${dept}-${id}", dept = dept, id = id }]
    ]) : pair.key => pair
  }
  group_object_id  = azuread_group.dept[each.value.dept].object_id
  member_object_id = each.value.id
}

resource "azurerm_storage_account" "dept" {
  for_each                        = var.departments
  name                            = "stlab${each.key}${random_string.suffix.result}"
  resource_group_name             = data.azurerm_resource_group.lab.name
  location                        = data.azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  tags = {
    lab        = "cloud-lab"
    layer      = "1"
    domain     = "identity"
    department = each.key
  }
}

# The operator needs data rights to create containers when shared keys are off.
data "azurerm_client_config" "me" {}

resource "azurerm_role_assignment" "operator" {
  for_each             = var.departments
  scope                = azurerm_storage_account.dept[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.me.object_id
}

resource "time_sleep" "rbac" {
  depends_on      = [azurerm_role_assignment.operator]
  create_duration = "60s"
}

resource "azurerm_storage_container" "dept" {
  for_each              = var.departments
  name                  = each.value
  storage_account_id    = azurerm_storage_account.dept[each.key].id
  container_access_type = "private"
  depends_on            = [time_sleep.rbac]
}

resource "azurerm_role_assignment" "group_reader" {
  for_each             = var.departments
  scope                = "${azurerm_storage_account.dept[each.key].id}/blobServices/default/containers/${azurerm_storage_container.dept[each.key].name}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_group.dept[each.key].object_id
}
