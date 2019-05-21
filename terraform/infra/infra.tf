data "azurerm_client_config" "current" {}

locals {
  base_name = "${substr(sha256(azurerm_resource_group.infra_rg.id), 0, 12)}"
  kv_name   = "kv${local.base_name}"
  vnet_name = "vnet${local.base_name}"
  storage_diag_logs_name   = "sa${local.base_name}"
}

resource "azurerm_resource_group" "infra_rg" {
  name     = "${var.infra_resource_group_name}"
  location = "${var.location}"
}

resource "azurerm_user_assigned_identity" "pipeline_identity" {
  name                 = "pipeline_identity"
  resource_group_name  = "${azurerm_resource_group.infra_rg.name}"
  location             = "${azurerm_resource_group.infra_rg.location}"
}

resource "azurerm_user_assigned_identity" "visualization_identity" {
  name                 = "visualization_identity"
  resource_group_name  = "${azurerm_resource_group.infra_rg.name}"
  location             = "${azurerm_resource_group.infra_rg.location}"
}

resource "azurerm_key_vault" "kv" {
  name                = "${local.kv_name}"
  location            = "${azurerm_resource_group.infra_rg.location}"
  resource_group_name = "${azurerm_resource_group.infra_rg.name}"
  tenant_id           = "${data.azurerm_client_config.current.tenant_id}"

  sku {
    name = "standard"
  }
}

resource "azurerm_storage_account" "diagnostic_logs" {
  name        = "${local.storage_diag_logs_name}"
  location            = "${azurerm_resource_group.infra_rg.location}"
  resource_group_name = "${azurerm_resource_group.infra_rg.name}"
  account_tier = "Standard"
  account_replication_type = "LRS"
  enable_blob_encryption = true
  enable_https_traffic_only = true
  network_rules {
    bypass = ["AzureServices"]
    virtual_network_subnet_ids = ["${azurerm_subnet.sandbox.id}"]
  }
}

resource "azurerm_key_vault_access_policy" "pipeline_identity" {
  key_vault_id = "${azurerm_key_vault.kv.id}"

  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${azurerm_user_assigned_identity.pipeline_identity.principal_id}"

  secret_permissions = [
    "list",
    "get",
  ]
}

resource "azurerm_key_vault_access_policy" "visualization_identity" {
  key_vault_id = "${azurerm_key_vault.kv.id}"

  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${azurerm_user_assigned_identity.visualization_identity.principal_id}"

  secret_permissions = [
    "list",
    "get",
  ]
}

resource "azurerm_key_vault_access_policy" "ado_service_connection" {
  key_vault_id = "${azurerm_key_vault.kv.id}"

  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${data.azurerm_client_config.current.service_principal_object_id}"

  secret_permissions = [
    "list",
    "get",
    "set",
  ]
}

resource "azurerm_key_vault_secret" "grafana_aad_client_secret" {
  name     = "grafana-aad-secret"
  value    = "${var.grafana_aad_client_secret}"
  key_vault_id = "${azurerm_key_vault.kv.id}"
  depends_on = ["azurerm_key_vault_access_policy.ado_service_connection"]
}

resource "azurerm_network_security_group" "sandboxNSG" {
  name                = "nsg-sandbox"
  location            = "${azurerm_resource_group.infra_rg.location}"
  resource_group_name = "${azurerm_resource_group.infra_rg.name}"

  security_rule {
    name                       = "allow-ssh"
    direction                  = "Inbound"
    priority                   = 100
    access                     = "Allow"
    description                = "Allow SSH to sandbox VMs."
    source_address_prefix      = "*"
    source_port_range          = "*"
    protocol                   = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "allow-https"
    direction                  = "Inbound"
    priority                   = 110
    access                     = "Allow"
    description                = "Allow HTTPS to sandbox VMs."
    source_address_prefix      = "*"
    source_port_range          = "*"
    protocol                   = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "allow-pipeline"
    direction                  = "Inbound"
    priority                   = 120
    access                     = "Allow"
    description                = "Allow TCP 57500 to sandbox VMs."
    source_address_prefix      = "*"
    source_port_range          = "*"
    protocol                   = "*"
    destination_address_prefix = "*"
    destination_port_range     = "57500"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.vnet_name}"
  location            = "${azurerm_resource_group.infra_rg.location}"
  resource_group_name = "${azurerm_resource_group.infra_rg.name}"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "sandbox" {
  name                 = "sandbox"
  resource_group_name  = "${azurerm_resource_group.infra_rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.0.1.0/24"
  service_endpoints    = ["Microsoft.EventHub", "Microsoft.Storage", "Microsoft.KeyVault"]
  network_security_group_id = "${azurerm_network_security_group.sandboxNSG.id}"
}

resource "azurerm_subnet_network_security_group_association" "sandboxNSGAssociation" {
  subnet_id                 = "${azurerm_subnet.sandbox.id}"
  network_security_group_id = "${azurerm_network_security_group.sandboxNSG.id}"
}

output "keyvault_id" {
  value = "${azurerm_key_vault.kv.id}"
}

output "vnet_id" {
  value = "${azurerm_virtual_network.vnet.id}"
}

output "sandbox_subnet_id" {
  value = "${azurerm_subnet.sandbox.id}"
}

output "pipeline_identity_id" {
  value = "${azurerm_user_assigned_identity.pipeline_identity.id}"
}

output "visualization_identity_id" {
  value = "${azurerm_user_assigned_identity.visualization_identity.id}"
}

output "storage_diagnostics_logs_id" {
  value = "${azurerm_storage_account.diagnostic_logs.id}"
}

output "grafana_aad_client_secret_keyvault_secret_id" {
  value = "${azurerm_key_vault_secret.grafana_aad_client_secret.id}"
}