# Layer 1: everything here is destroyed after every session.
# The resource group is layer 0 and is only read, never managed, so destroy cannot remove it.
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

locals {
  tags = {
    lab   = "cloud-lab"
    layer = "1"
  }
}

# Domain exercises (identity, storage, networking, compute, monitoring) are added below,
# each as its own file, e.g. compute.tf. Empty for now on purpose: CLOUD-23 proves
# the destroy path against an empty target before anything billable exists.
