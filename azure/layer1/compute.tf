# CLOUD-28 compute (layer 1, destroyed after every session).
# The Terraform twin of the console build of 12 Oct 2026: one free-tier VM with no public IP and no
# inbound rule. Nobody logs in; the exercise is the power states and the hours each one bills.
#
# Differences from the console build, on purpose:
#   - The VM goes into the shared layer 0 resource group (read-only data source), not into a group of
#     its own. Destroy therefore removes the resources one by one and never the group.
#   - No Bastion and no public IP. Both bill by the hour and neither is needed to read power states.
#   - No auto-shutdown: Denmark East does not support it (observed 12 Oct), so the safety net is the
#     operator's clock plus scripts/teardown.sh.
#   - The SSH key is generated here (tls provider) because Azure requires one. It lives in layer 1
#     state and disappears with the VM. Nobody uses it.
#
# Verified on 14 Oct 2026 after the first apply: the OS disk carries domain=compute and layer=1 even
# though the os_disk block has no tags argument (the VM's tags reach the disk it creates). The console
# build of 12 Oct did not tag its disk. docs/runbooks/compute-session.md repeats the check.

variable "compute_location" {
  description = "Region for the compute exercise. Not the layer 0 group's region: B1s was refused in East US 2 for this subscription (NotAvailableForSubscription) and was accepted in Denmark East."
  type        = string
  default     = "denmarkeast"
}

variable "vm_size" {
  description = "Only the x64 free burstable sizes of the Azure free account (750 hours a month). Standard_B2pts_v2 is also free but is ARM-based and would need an arm64 image."
  type        = string
  default     = "Standard_B1s"

  validation {
    condition     = contains(["Standard_B1s", "Standard_B2ats_v2"], var.vm_size)
    error_message = "CLOUD-28 rule: no VM outside the free burstable types. Allowed here: Standard_B1s, Standard_B2ats_v2."
  }
}

variable "vm_zone" {
  description = "Availability zone. The console build used zone 1 in Denmark East."
  type        = string
  default     = "1"
}

variable "admin_username" {
  description = "Administrator account name. Required by Azure; nobody logs in."
  type        = string
  default     = "azureuser"
}

resource "azurerm_virtual_network" "compute" {
  name                = "vnet-cloud-lab-compute"
  location            = var.compute_location
  resource_group_name = data.azurerm_resource_group.lab.name
  address_space       = ["10.60.0.0/16"]
  tags                = merge(local.tags, { domain = "compute" })
}

resource "azurerm_subnet" "compute" {
  name                 = "snet-cloud-lab-compute"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.compute.name
  address_prefixes     = ["10.60.1.0/24"]
}

# No custom rules: Azure's default rules already refuse inbound traffic from the internet.
resource "azurerm_network_security_group" "compute" {
  name                = "nsg-cloud-lab-compute"
  location            = var.compute_location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = merge(local.tags, { domain = "compute" })
}

# No public_ip_address_id on purpose.
resource "azurerm_network_interface" "compute" {
  name                = "nic-cloud-lab-compute"
  location            = var.compute_location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = merge(local.tags, { domain = "compute" })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.compute.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "compute" {
  network_interface_id      = azurerm_network_interface.compute.id
  network_security_group_id = azurerm_network_security_group.compute.id
}

resource "tls_private_key" "compute" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Canonical's own Ubuntu Server 24.04 LTS image, the same one the wizard offered. A third-party
# Marketplace image would add an hourly software charge.
resource "azurerm_linux_virtual_machine" "compute" {
  name                            = "vm-cloud-lab-compute"
  resource_group_name             = data.azurerm_resource_group.lab.name
  location                        = var.compute_location
  size                            = var.vm_size
  zone                            = var.vm_zone
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.compute.id]
  tags                            = merge(local.tags, { domain = "compute" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.compute.public_key_openssh
  }

  # Standard SSD, as in the console build. The provider deletes the OS disk with the VM.
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  depends_on = [azurerm_network_interface_security_group_association.compute]
}

# Image capture (CLOUD-28, second session). An incremental snapshot of the OS disk: the Azure
# counterpart of an EBS snapshot, and the image of this exercise. A generalized managed image would
# need the VM deprovisioned from inside, which this lab cannot do (no login path, on purpose), and
# it would leave the VM unusable. The snapshot is crash-consistent, taken while the VM runs.
# It is a separate resource so that "apply the VM", "resize", and "snapshot" are three plans.
resource "azurerm_snapshot" "compute" {
  name                = "snap-cloud-lab-compute"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = var.compute_location
  create_option       = "Copy"
  source_uri          = azurerm_linux_virtual_machine.compute.os_managed_disk_id
  incremental_enabled = true
  tags                = merge(local.tags, { domain = "compute" })
}
