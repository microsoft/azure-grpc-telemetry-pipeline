variable "infra_resource_group_name" {
  type = "string"
}

variable "location" {
  type    = "string"
  default = "westus2"
}

variable "grafana_aad_client_secret" {
  description = "Grafana AAD client id secret value. This will be stored in KeyVault."
  type = "string"
}