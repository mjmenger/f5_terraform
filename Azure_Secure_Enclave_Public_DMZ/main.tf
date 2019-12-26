# Create a Resource Group for the new Virtual Machine
resource "azurerm_resource_group" "main" {
  name			= "${var.prefix}_rg"
  location = var.location
}

# Create Log Analytic Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                  = "${var.prefix}-law"
  sku                   = "PerNode"
  retention_in_days     = 300
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
}



# Create a Public IP for the Virtual Machines
resource "azurerm_public_ip" "vm01mgmtpip" {
  name			          = "${var.prefix}-vm01-mgmt-pip"
  location		        = azurerm_resource_group.main.location
  resource_group_name	= azurerm_resource_group.main.name
  allocation_method	  = "Dynamic"

  tags = {
    Name		      = "${var.environment}-vm01-mgmt-public-ip"
    environment		= var.environment
    owner		      = var.owner
    group		      = var.group
    costcenter		= var.costcenter
    application		= var.application
  }
}

resource "azurerm_public_ip" "vm02mgmtpip" {
  name			            = "${var.prefix}-vm02-mgmt-pip"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  allocation_method	    = "Dynamic"

  tags = {
    Name		      = "${var.environment}-vm02-mgmt-public-ip"
    environment		= var.environment
    owner		      = var.owner
    group		      = var.group
    costcenter		= var.costcenter
    application		= var.application
  }
}


resource "azurerm_public_ip" "lbpip" {
  name                  = "${var.prefix}-lb-pip"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  allocation_method	    = "Dynamic"
  domain_name_label     = "${var.prefix}lbpip"
}

# Create Availability Set
resource "azurerm_availability_set" "avset" {
  name                          = "${var.prefix}avset"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  platform_fault_domain_count   = 2
  platform_update_domain_count  = 2
  managed                       = true
}

# Create Azure LB
resource "azurerm_lb" "lb" {
  name                = "${var.prefix}lb"
  location            = azurerm_resource_group.main.location
  resource_group_name	= azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                = "LoadBalancerFrontEnd"
    public_ip_address_id	= azurerm_public_ip.lbpip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "BackendPool1"
  resource_group_name	= azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name	  = azurerm_resource_group.main.name
  loadbalancer_id       = azurerm_lb.lb.id
  name                  = "tcpProbe"
  protocol              = "tcp"
  port                  = 8443
  interval_in_seconds   = 5
  number_of_probes      = 2
}

resource "azurerm_lb_rule" "lb_rule1" {
  name                            = "LBRule1"
  resource_group_name             = azurerm_resource_group.main.name
  loadbalancer_id                 = azurerm_lb.lb.id
  protocol                        = "tcp"
  frontend_port                   = 443
  backend_port                    = 8443
  frontend_ip_configuration_name  = "LoadBalancerFrontEnd"
  enable_floating_ip    	        = false
  backend_address_pool_id	        = azurerm_lb_backend_address_pool.backend_pool.id
  idle_timeout_in_minutes         = 5
  probe_id                        = azurerm_lb_probe.lb_probe.id
  depends_on                      = [azurerm_lb_probe.lb_probe]
}

resource "azurerm_lb_rule" "lb_rule2" {
  name                            = "LBRule2"
  resource_group_name             = azurerm_resource_group.main.name
  loadbalancer_id                 = azurerm_lb.lb.id
  protocol                        = "tcp"
  frontend_port                   = 80
  backend_port                    = 80
  frontend_ip_configuration_name  = "LoadBalancerFrontEnd"
  enable_floating_ip              = false
  backend_address_pool_id         = azurerm_lb_backend_address_pool.backend_pool.id
  idle_timeout_in_minutes         = 5
  probe_id                        = azurerm_lb_probe.lb_probe.id
  depends_on                      = [azurerm_lb_probe.lb_probe]
}

# Create a Network Security Group with some rules
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_HTTP"
    description                = "Allow HTTP access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_RDP"
    description                = "Allow RDP access"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_APP_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Name           = "${var.environment}-bigip-sg"
    environment    = var.environment
    owner          = var.owner
    group          = var.group
    costcenter     = var.costcenter
    application    = var.application
  }
}












# Associate the Network Interface to the BackendPool
resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm01" {
  depends_on              = [azurerm_lb_backend_address_pool.backend_pool, azurerm_network_interface.vm01-ext-nic]
  network_interface_id    = azurerm_network_interface.vm01-ext-nic.id
  ip_configuration_name   = "secondary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm02" {
  depends_on              = [azurerm_lb_backend_address_pool.backend_pool, azurerm_network_interface.vm02-ext-nic]
  network_interface_id    = azurerm_network_interface.vm02-ext-nic.id
  ip_configuration_name   = "secondary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

## OUTPUTS ###
data "azurerm_public_ip" "vm01mgmtpip" {
  name                = format("%s-publicip01-%s",var.prefix,random_id.tag.hex)
  resource_group_name = azurerm_resource_group.main.name
  depends_on          = [azurerm_virtual_machine.f5vm01]
}
data "azurerm_public_ip" "vm02mgmtpip" {
  name                = format("%s-publicip02-%s",var.prefix,random_id.tag.hex)
  resource_group_name = azurerm_resource_group.main.name
  depends_on          = [azurerm_virtual_machine.f5vm02]
}
data "azurerm_public_ip" "lbpip" {
  name                = format("%s-publiciplb-%s",var.prefix,random_id.tag.hex)
  resource_group_name = azurerm_resource_group.main.name
  depends_on          = [azurerm_virtual_machine.f5vm02]
}

output "sg_id" { value = azurerm_network_security_group.main.id }
output "sg_name" { value = azurerm_network_security_group.main.name }
output "mgmt_subnet_gw" { value = local.mgmt_gw }
output "ext_subnet_gw" { value = local.ext_gw }
output "ALB_app1_pip" { value = data.azurerm_public_ip.lbpip.ip_address }



