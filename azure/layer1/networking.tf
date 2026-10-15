# CLOUD-27 networking (layer 1, destroyed after every session).
# The Terraform twin of the console build of 15 Oct 2026: one virtual network with a web and a db
# subnet, a security group on each, a storage account reached through a private endpoint with
# private DNS, and one small VM in the web subnet as the client. Nothing here has a public IP.
#
# The console session ran in phases, and the variables below reproduce them as separate plans:
#   A. defaults:                    the endpoint exists and the NSG is ignored for traffic to it.
#   B. net_pe_nsg_enforced = true:  the db subnet applies its NSG to the endpoint, rule 300 denies.
#   C. + net_allow_web_to_pe = true: rule 150 lets 443 reach the endpoint again.
#   D. + net_public_access = false: the account refuses the public network.
# Each phase is read from inside the VM with `az vm run-command invoke`, so there is no login path.
#
# Prices (Azure list, stated before running): private endpoint 0.01 USD an hour, VM B1s 0.0120 USD an
# hour, private DNS zone about 0.50 USD a month. Network, subnets, NSGs and the storage account at rest
# are free, and none of their creation screens shows a price.
# Tags: lab and layer from local.tags; domain = networking on every resource.

variable "network_location" {
  description = "Region of the networking exercise. Same as the console build and the compute exercise."
  type        = string
  default     = "denmarkeast"
}

variable "net_pe_nsg_enforced" {
  description = "false: the db subnet ignores its NSG for private endpoint traffic (portal default, console phase A). true: the NSG applies (phase B onward)."
  type        = bool
  default     = false
}

variable "net_allow_web_to_pe" {
  description = "true adds rule 150, which allows 443 from the web subnet to the endpoint (phase C onward)."
  type        = bool
  default     = false
}

variable "net_public_access" {
  description = "true: the account accepts public network traffic (portal default). false: only the endpoint reaches it (phase D)."
  type        = bool
  default     = true
}

resource "random_string" "net_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_virtual_network" "net" {
  name                = "vnet-cloud-lab-net"
  location            = var.network_location
  resource_group_name = data.azurerm_resource_group.lab.name
  address_space       = ["10.70.0.0/16"]
  tags                = merge(local.tags, { domain = "networking" })
}

resource "azurerm_subnet" "net_web" {
  name                 = "snet-web"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.net.name
  address_prefixes     = ["10.70.1.0/24"]
}

resource "azurerm_subnet" "net_db" {
  name                 = "snet-db"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.net.name
  address_prefixes     = ["10.70.2.0/24"]

  # The setting the console build found by surprise: with "Disabled" (the portal default) the NSG
  # of this subnet is not applied to traffic that goes to a private endpoint in it.
  private_endpoint_network_policies = var.net_pe_nsg_enforced ? "NetworkSecurityGroupEnabled" : "Disabled"
}

resource "azurerm_network_security_group" "net_web" {
  name                = "nsg-cloud-lab-net-web"
  location            = var.network_location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = merge(local.tags, { domain = "networking" })
}

resource "azurerm_network_security_group" "net_db" {
  name                = "nsg-cloud-lab-net-db"
  location            = var.network_location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = merge(local.tags, { domain = "networking" })
}

resource "azurerm_subnet_network_security_group_association" "net_web" {
  subnet_id                 = azurerm_subnet.net_web.id
  network_security_group_id = azurerm_network_security_group.net_web.id
}

resource "azurerm_subnet_network_security_group_association" "net_db" {
  subnet_id                 = azurerm_subnet.net_db.id
  network_security_group_id = azurerm_network_security_group.net_db.id
}

resource "azurerm_network_security_rule" "net_web_https" {
  name                        = "allow-https-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.net_web.name
}

resource "azurerm_network_security_rule" "net_db_sql_from_web" {
  name                        = "allow-sql-from-web"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "10.70.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.net_db.name
}

# Phase C only. Destination is the endpoint's own address, so 443 is the one door left open.
resource "azurerm_network_security_rule" "net_db_allow_web_to_pe" {
  count = var.net_allow_web_to_pe ? 1 : 0

  name                        = "allow-web-to-pe"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.70.1.0/24"
  destination_address_prefix  = "${azurerm_private_endpoint.net.private_service_connection[0].private_ip_address}/32"
  resource_group_name         = data.azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.net_db.name
}

# Azure's default rules (65000 AllowVnetInBound and up) let the web subnet reach the db subnet,
# because both are in one virtual network. This is the explicit deny that closes it.
resource "azurerm_network_security_rule" "net_db_deny_internet" {
  name                        = "deny-internet-in"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.net_db.name
}

resource "azurerm_network_security_rule" "net_db_deny_web_other" {
  name                        = "deny-web-other"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.70.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.net_db.name
}

# Defaults as the console wizard left them, except redundancy (LRS) and no public blob access.
resource "azurerm_storage_account" "net" {
  name                     = "stlabnet${random_string.net_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.lab.name
  location                 = var.network_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false
  public_network_access_enabled   = var.net_public_access

  tags = merge(local.tags, { domain = "networking" })
}

resource "azurerm_private_dns_zone" "net_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = merge(local.tags, { domain = "networking" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "net_blob" {
  name                  = "link-cloud-lab-net"
  resource_group_name   = data.azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.net_blob.name
  virtual_network_id    = azurerm_virtual_network.net.id
  registration_enabled  = false
  tags                  = merge(local.tags, { domain = "networking" })
}

# Bills 0.01 USD an hour from creation. Always present in this file, so every phase pays for it.
resource "azurerm_private_endpoint" "net" {
  name                = "pe-cloud-lab-net-blob"
  location            = var.network_location
  resource_group_name = data.azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.net_db.id

  private_service_connection {
    name                           = "psc-cloud-lab-net-blob"
    private_connection_resource_id = azurerm_storage_account.net.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.net_blob.id]
  }

  tags = merge(local.tags, { domain = "networking" })
}

# The client. No public IP, no NIC-level NSG (the subnet's applies), nobody logs in.
resource "azurerm_network_interface" "net_client" {
  name                = "nic-cloud-lab-net-client"
  location            = var.network_location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = merge(local.tags, { domain = "networking" })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.net_web.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "net_client" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "net_client" {
  name                            = "vm-cloud-lab-net-client"
  resource_group_name             = data.azurerm_resource_group.lab.name
  location                        = var.network_location
  size                            = var.vm_size
  zone                            = var.vm_zone
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.net_client.id]
  tags                            = merge(local.tags, { domain = "networking" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.net_client.public_key_openssh
  }

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

  depends_on = [azurerm_subnet_network_security_group_association.net_web]
}

output "net_vm_name" {
  description = "Client VM of the CLOUD-27 exercise, for az vm run-command."
  value       = azurerm_linux_virtual_machine.net_client.name
}

output "net_storage_account" {
  description = "Storage account behind the private endpoint."
  value       = azurerm_storage_account.net.name
}

output "net_endpoint_ip" {
  description = "Private address of the endpoint, read from the API after creation."
  value       = azurerm_private_endpoint.net.private_service_connection[0].private_ip_address
}
