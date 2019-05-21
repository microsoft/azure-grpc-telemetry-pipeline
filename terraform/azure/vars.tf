locals {
  baseName = "${substr(sha256(azurerm_resource_group.rg.id), 0, 12)}"
  virtual_machine_user_name = "azureuser"
}

# Common properties

variable "resource_group_name" {
  description = "The name of the resource group."
}

variable "location" {
  description = "The location/region where the resources are created."
}

# Infra

variable "infra_sandbox_subnet_id" {
  description = "Name of the subnet to be used for the sandbox"
  type = "string"
}

variable "infra_diagnostic_log_storage_account_id" {
  description = "Resource id for the storage account storing Azure Monitor diagnostic logs"
  type = "string"
}

# Pipeline VM 

variable "pipeline_custom_image_id" {
  description = "Pipeline custom VM image resourceId"
  type = "string"
}

variable "pipeline_user_identities" {
  description = "User assigned identities for the pipeline virtual machine"
  type = "list"
}

# Visualization VM

variable "visualization_custom_image_id" {
  description = "Visualization custom VM image resourceId"
  type = "string"
}

variable "visualization_user_identities" {
  description = "User assigned identities for the visualization virtual machine"
  type = "list"
}


# General VM settings

variable "vm_size" {
  description = "Size of VMs"
  type = "string"
  default = "Standard_D2_V2"
}


# EventHub

variable "event_hub_subnet_ids" {
  description = "IDs of subnets. Event Hub Namespace will only accept connections from these subnets."
  type = "string"
}

variable "partition_count" {
  description = "The number of partitions must be between 2 and 32. The partition count is not changeable."
  type = "string"
  default = "4"
}
variable "message_retention_in_days" {
  description = "The Event Hubs Standard tier allows message retention period for a maximum of seven days."
  type = "string"
  default = "7"
}

# Key Vault

variable "key_vault_id" {
  description = "Resource ID of the Key Vault to be used for storing application secrets."
  "type" = "string"
}

# Grafana

variable "grafana_aad_client_id" {
  description = "Client id used for Grafana AAD authentication."
  "type" = "string"
}

variable "grafana_aad_client_secret_keyvault_secret_id" {
  description = "Client secret Key Vault id for Grafana AAD authentication."
  "type" = "string"
}

variable "grafana_aad_directory_id" {
  description = "Directory id used for Grafana AAD authentication."
  "type" = "string"
}

variable "grafana_root_url" {
  description = "Root url used for Grafana AAD authentication."
  "type" = "string"
}