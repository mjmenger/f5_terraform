# Create a Virtual Network within the Resource Group
resource "azurerm_virtual_network" "main" {
  name			= "${var.prefix}-hub"
  address_space		= [var.cidr]
  resource_group_name	= azurerm_resource_group.main.name
  location		= azurerm_resource_group.main.location
}

# Create a Virtual Network within the Resource Group
resource "azurerm_virtual_network" "spoke" {
  name                  = "${var.prefix}-spoke"
  address_space         = [var.app-cidr]
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
}

# Create the Mgmt Subnet within the Hub Virtual Network
resource "azurerm_subnet" "Mgmt" {
  name			= "Mgmt"
  virtual_network_name	= azurerm_virtual_network.main.name
  resource_group_name	= azurerm_resource_group.main.name
  address_prefix	= var.subnets["subnet1"]
}

# Create the External Subnet within the Hub Virtual Network
resource "azurerm_subnet" "External" {
  name			= "External"
  virtual_network_name	= azurerm_virtual_network.main.name
  resource_group_name	= azurerm_resource_group.main.name
  address_prefix	= var.subnets["subnet2"]
}

# Create the App1 Subnet within the Spoke Virtual Network
resource "azurerm_subnet" "App1" {
  name                  = "App1"
  virtual_network_name  = azurerm_virtual_network.spoke.name
  resource_group_name   = azurerm_resource_group.main.name
  address_prefix        = var.app-subnets["subnet1"]
}

# Obtain Gateway IP for each Subnet
locals {
  depends_on = [azurerm_subnet.Mgmt, azurerm_subnet.External]
  mgmt_gw    = cidrhost(azurerm_subnet.Mgmt.address_prefix, 1)
  ext_gw     = cidrhost(azurerm_subnet.External.address_prefix, 1)
  app1_gw    = cidrhost(azurerm_subnet.App1.address_prefix, 1)
}

# Create Network Peerings
resource "azurerm_virtual_network_peering" "HubToSpoke" {
  name                      = "HubToSpoke"
  depends_on                = [azurerm_virtual_machine.backendvm]
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "SpokeToHub" {
  name                      = "HubToSpoke"
  depends_on                = [azurerm_virtual_machine.backendvm]
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.main.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}