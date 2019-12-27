# Create interfaces for the BIGIPs 
locals {
    region               = azurerm_resource_group.main.location
    bigip_instance_count = var.bigip_count
    resourcegroup        = azurerm_resource_group.main.name
    securitygroup        = azurerm_network_security_group.main.id
    managementip         = [var.f5vm01mgmt,var.f5vm02mgmt]
    externalprimaryip    = [var.f5vm01ext,var.f5vm02ext]
    externalsecondaryip  = [var.f5vm01ext_sec,var.f5vm02ext_sec]
}


resource "azurerm_network_interface" "vm01-mgmt-nic" {
    count                     = local.bigip_instance_count
    name                      = format("%s-vm%0d-mgmt-nic",var.prefix,count.index)
    location                  = local.region
    resource_group_name       = local.resourcegroup
    network_security_group_id = local.securitygroup

    ip_configuration {
        name                          = "primary"
        subnet_id                     = azurerm_subnet.Mgmt.id
        private_ip_address_allocation = "Static"
        private_ip_address            = local.managementip[count.index]
        public_ip_address_id          = azurerm_public_ip.vm01mgmtpip[count.index].id 
    }

    tags = {
        Name           = format("%s-%s-vm%0d-mgmt-nic",var.prefix,var.environment,count.index)
        environment    = var.environment
        owner          = var.owner
        group          = var.group
        costcenter     = var.costcenter
        application    = var.application
    }
}

resource "azurerm_network_interface" "vm01-ext-nic" {
    count                     = local.bigip_instance_count
    name                      = format("%s-vm%0d-ext-nic",var.prefix,count.index)
    location                  = local.region
    resource_group_name       = local.resourcegroup
    network_security_group_id = local.securitygroup
    enable_ip_forwarding      = true
    depends_on                = [azurerm_lb_backend_address_pool.backend_pool]

    ip_configuration {
        name                          = "primary"
        subnet_id                     = azurerm_subnet.External.id
        private_ip_address_allocation = "Static"
        private_ip_address            = local.externalprimaryip[count.index]
        primary                       = true
    }

    ip_configuration {
        name                          = "secondary"
        subnet_id                     = azurerm_subnet.External.id
        private_ip_address_allocation = "Static"
        private_ip_address            = local.externalsecondaryip[count.index]
    }

    tags = {
        Name           = format("%s-%s-vm%0d-ext-nic",var.prefix,var.environment,count.index)
        environment    = var.environment
        owner          = var.owner
        group          = var.group
        costcenter     = var.costcenter
        application    = var.application
    }
}



# Create F5 BIGIP VMs
resource "azurerm_virtual_machine" "f5vm01" {
    count                        = local.bigip_instance_count
    name                         = format("%s-vm%0d-%s-%s",var.prefix,count.index,var.environment,random_id.tag.hex)
    location                     = azurerm_resource_group.main.location
    depends_on                   = [azurerm_virtual_machine.backendvm]
    resource_group_name          = azurerm_resource_group.main.name
    primary_network_interface_id = azurerm_network_interface.vm01-mgmt-nic[count.index].id
    network_interface_ids        = [azurerm_network_interface.vm01-mgmt-nic[count.index].id, azurerm_network_interface.vm01-ext-nic[count.index].id]
    vm_size                      = var.instance_type
    availability_set_id          = azurerm_availability_set.avset.id

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    delete_os_disk_on_termination = true


    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher = "f5-networks"
        offer     = var.product
        sku       = var.image_name
        version   = var.bigip_version
    }

    storage_os_disk {
        name              = format("%s-vm%0d-osdisk-%s-%s",var.prefix,count.index,var.environment,random_id.tag.hex)
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "80"
    }

    os_profile {
        computer_name  = format("%s-vm%0d-%s-%s",var.prefix,count.index,var.environment,random_id.tag.hex)
        admin_username = var.uname
        admin_password = var.upassword
        custom_data    = data.template_file.vm_onboard.rendered
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    plan {
        name          = var.image_name
        publisher     = "f5-networks"
        product       = var.product
    }

    tags = {
        Name           = format("%s-vm%0d-%s-%s",var.prefix,count.index,var.environment,random_id.tag.hex)
        environment    = var.environment
        owner          = var.owner
        group          = var.group
        costcenter     = var.costcenter
        application    = var.application
    }
}

# Run Startup Script
resource "azurerm_virtual_machine_extension" "f5vm01_run_startup_cmd" {
    count                = local.bigip_instance_count
    name                 = "${var.environment}_f5vm01_run_startup_cmd"
    depends_on           = [azurerm_virtual_machine.f5vm01]
    location             = var.region
    resource_group_name  = azurerm_resource_group.main.name
    virtual_machine_name = azurerm_virtual_machine.f5vm01[count.index].name
    publisher            = "Microsoft.OSTCExtensions"
    type                 = "CustomScriptForLinux"
    type_handler_version = "1.2"

    settings = <<SETTINGS
        {
            "commandToExecute": "bash /var/lib/waagent/CustomData"
        }
    SETTINGS

    tags = {
        Name           = "${var.environment}_f5vm01_startup_cmd"
        environment    = var.environment
        owner          = var.owner
        group          = var.group
        costcenter     = var.costcenter
        application    = var.application
    }
}

# Setup Onboarding scripts
data "template_file" "vm_onboard" {
    template = "${file("${path.module}/onboard.tpl")}"

    vars = {
        uname          = var.uname
        upassword      = var.upassword
        DO_onboard_URL = var.DO_onboard_URL
        AS3_URL        = var.AS3_URL
        TS_URL         = var.TS_URL
        libs_dir       = var.libs_dir
        onboard_log    = var.onboard_log
    }
}

# data "template_file" "vm01_do_json" {
#     count    = local.bigip_instance_count
#     template = file("${path.module}/cluster.json")

#     vars = {
#         #Uncomment the following line for BYOL
#         regkey         = var.license1
#         host1          = var.host1_name
#         host2          = var.host2_name
#         local_host     = var.host1_name
#         local_selfip1  = local.externalprimaryip[count.index]
#         remote_selfip  = local.externalprimaryip[count.index]
#         gateway        = local.ext_gw
#         dns_server     = var.dns_server
#         ntp_server     = var.ntp_server
#         timezone       = var.timezone
#         admin_user     = var.uname
#         admin_password = var.upassword
#     }
# }

# data "template_file" "as3_json" {
#     template = "${file("${path.module}/as3.json")}"

#     vars = {
#         backendvm_ip    = var.backend01ext
#         rg_name         = azurerm_resource_group.main.name
#         subscription_id = var.SP["subscription_id"]
#         tenant_id       = var.SP["tenant_id"]
#         client_id       = var.SP["client_id"]
#         client_secret   = var.SP["client_secret"]
#     }
# }

# data "template_file" "ts_json" {
#     template   = "${file("${path.module}/ts.json")}"
#     depends_on = [azurerm_log_analytics_workspace.law]
#     vars       = {
#         law_id          = azurerm_log_analytics_workspace.law.workspace_id
#         law_primkey     = azurerm_log_analytics_workspace.law.primary_shared_key
#     }
# }

# # Run REST API for configuration
# resource "local_file" "vm01_do_file" {
#     count    = local.bigip_instance_count
#     content  = data.template_file.vm01_do_json[count.index].rendered
#     filename = "${path.module}/${var.rest_vm01_do_file}"
# }

# resource "local_file" "vm_as3_file" {
#     content  = data.template_file.as3_json.rendered
#     filename = "${path.module}/${var.rest_vm_as3_file}"
# }

# resource "local_file" "vm_ts_file" {
#     content  = data.template_file.ts_json.rendered
#     filename = "${path.module}/${var.rest_vm_ts_file}"
# }

# resource "null_resource" "f5vm01_DO" {
#     count      = local.bigip_instance_count
#     depends_on = [azurerm_virtual_machine_extension.f5vm01_run_startup_cmd]
#     # Running DO REST API
#     provisioner "local-exec" {
#         command = <<-EOF
#         #!/bin/bash
#         curl -k -X ${var.rest_do_method} https://${data.azurerm_public_ip.vm01mgmtpip[count.index].ip_address}${var.rest_do_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm01_do_file}
#         x=1; while [ $x -le 30 ]; do STATUS=$(curl -k -X GET https://${data.azurerm_public_ip.vm01mgmtpip[count.index].ip_address}/mgmt/shared/declarative-onboarding/task -u ${var.uname}:${var.upassword}); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
#         sleep 120
#         EOF
#     }
# }

# resource "null_resource" "f5vm01_TS" {
#     count      = local.bigip_instance_count
#     depends_on = [null_resource.f5vm01_DO]
#     # Running CF REST API
#     provisioner "local-exec" {
#         command = <<-EOF
#         #!/bin/bash
#         curl -H 'Content-Type: application/json' -k -X POST https://${data.azurerm_public_ip.vm01mgmtpip[count.index].ip_address}${var.rest_ts_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_ts_file}
#         EOF
#     }
# }

# resource "null_resource" "f5vm_AS3" {
#     count      = local.bigip_instance_count
#     depends_on = [null_resource.f5vm01_DO, null_resource.f5vm02_DO]
#     # Running AS3 REST API
#     provisioner "local-exec" {
#         command = <<-EOF
#         #!/bin/bash
#         curl -k -X ${var.rest_as3_method} https://${data.azurerm_public_ip.vm01mgmtpip[count.index].ip_address}${var.rest_as3_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_as3_file}
#         EOF
#     }
# }

output "f5vm01_id" { value = azurerm_virtual_machine.f5vm01[*].id }
output "f5vm01_mgmt_private_ip" { value = azurerm_network_interface.vm01-mgmt-nic[*].private_ip_address }
output "f5vm01_mgmt_public_ip" { value = data.azurerm_public_ip.vm01mgmtpip[*].ip_address }
output "f5vm01_ext_private_ip" { value = azurerm_network_interface.vm01-ext-nic[*].private_ip_address }