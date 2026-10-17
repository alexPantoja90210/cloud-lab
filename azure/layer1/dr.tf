# CLOUD-35: the restore half of the disaster recovery drill.
#
# The VM and the snapshot already exist in compute.tf. This file adds only a disk made from that snapshot.
# The VM that uses the restored disk is created with the Azure CLI (see docs/runbooks/dr-recovery-session.md):
# the azurerm provider documents that it does not support attaching existing OS disks.
#
# Off by default (dr_restore = false) so that plans and the teardown destroy never read the snapshot.
# The snapshot is read through a data source, not through azurerm_snapshot.compute, so that targeting the
# restored disk does not pull the original VM into the plan after the VM was deleted on purpose.

variable "dr_restore" {
  description = "CLOUD-35 drill only: create a disk from the existing compute snapshot."
  type        = bool
  default     = false
}

data "azurerm_snapshot" "compute_restore" {
  count               = var.dr_restore ? 1 : 0
  name                = "snap-cloud-lab-compute"
  resource_group_name = data.azurerm_resource_group.lab.name
}

resource "azurerm_managed_disk" "restored" {
  count                = var.dr_restore ? 1 : 0
  name                 = "disk-cloud-lab-restored"
  location             = var.compute_location
  resource_group_name  = data.azurerm_resource_group.lab.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Copy"
  source_resource_id   = data.azurerm_snapshot.compute_restore[0].id
  os_type              = "Linux"
  zone                 = var.vm_zone
  tags                 = merge(local.tags, { domain = "compute" })
}

output "restored_disk_name" {
  description = "Disk restored from the snapshot, for the VM that is created from it with the CLI."
  value       = try(azurerm_managed_disk.restored[0].name, null)
}
