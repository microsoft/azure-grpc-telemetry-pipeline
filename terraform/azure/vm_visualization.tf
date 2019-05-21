locals {
  visualization_name = "viz-${local.baseName}"
  grafana_auth_generic_oauth_auth_url="https://login.microsoftonline.com/${var.grafana_aad_directory_id}/oauth2/authorize"
  grafana_auth_generic_oauth_token_url="https://login.microsoftonline.com/${var.grafana_aad_directory_id}/oauth2/token"

}

resource "azurerm_network_interface" "visualization" {
  name                = "nic-${local.visualization_name}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "config1"
    subnet_id                     = "${var.infra_sandbox_subnet_id}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "visualization" {
  name                  = "${local.visualization_name}"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.visualization.id}"]
  vm_size               = "${var.vm_size}"

  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${var.visualization_custom_image_id}"
  }

  storage_os_disk {
    name              = "osdisk-${local.visualization_name}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.visualization_name}"
    admin_username = "${local.virtual_machine_user_name}"
    admin_password = "${uuid()}"
    custom_data = <<-EOF
BROKERS=${local.event_hub_namespace}.servicebus.windows.net:9093
SECRET_ID=${azurerm_key_vault_secret.reader_metrics.id}
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${var.grafana_aad_client_id}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET_KV_ID=${var.grafana_aad_client_secret_keyvault_secret_id}
GF_SERVER_ROOT_URL=${var.grafana_root_url} 
GF_AUTH_GENERIC_OAUTH_AUTH_URL=${local.grafana_auth_generic_oauth_auth_url}
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=${local.grafana_auth_generic_oauth_token_url}
  EOF
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  identity {
    type = "UserAssigned"
    identity_ids = "${var.visualization_user_identities}"
  }
}