locals {
  pipeline_name = "pipeline-${local.baseName}"
}

resource "azurerm_network_interface" "pipeline" {
  name                = "nic-${local.pipeline_name}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "config1"
    subnet_id                     = "${var.infra_sandbox_subnet_id}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "pipeline" {
  name                  = "${local.pipeline_name}"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.pipeline.id}"]
  vm_size               = "${var.vm_size}"

  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${var.pipeline_custom_image_id}"
  }

  storage_os_disk {
    name              = "osdisk-${local.pipeline_name}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.pipeline_name}"
    admin_username = "${local.virtual_machine_user_name}"
    admin_password = "${uuid()}"
    custom_data = <<-EOF
BROKERS=${local.event_hub_namespace}.servicebus.windows.net:9093
SECRET_ID=${azurerm_key_vault_secret.writer_pipeline.id}
  EOF
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  identity {
    type = "UserAssigned"
    identity_ids = "${var.pipeline_user_identities}"
  }
}