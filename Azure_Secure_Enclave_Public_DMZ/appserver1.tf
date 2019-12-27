# Create the Interface for the App server
resource "azurerm_network_interface" "backend01-ext-nic" {
    name                      = "${var.prefix}-backend01-ext-nic"
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    network_security_group_id = azurerm_network_security_group.main.id

    ip_configuration {
        name                          = "primary"
        subnet_id                     = azurerm_subnet.App1.id
        private_ip_address_allocation = "Static"
        private_ip_address            = var.backend01ext
        primary                       = true
    }

    tags = {
        foo = "bar"
    }
}

# backend VM
resource "azurerm_virtual_machine" "backendvm" {
    name                  = "backendvm"
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.backend01-ext-nic.id]
    vm_size               = "Standard_B1s"

    storage_os_disk {
        name              = "backendOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "backend01"
        admin_username = "azureuser"
        admin_password = var.upassword
        custom_data    = <<-EOF
        #!/bin/bash
        apt-get update -y
        apt-get install -y docker.io
        docker run -d -p 80:80 --net=host --restart unless-stopped vulnerables/web-dvwa
        EOF
}

    os_profile_linux_config {
        disable_password_authentication = false
    }

    tags = {
        application    = "app1"
    }
}