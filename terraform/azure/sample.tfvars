# common
resource_group_name = "network-telemetry-pipeline"
location = "westus2"

# infra
infra_sandbox_subnet_id = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Network/virtualNetworks/<VNET_NAME>/sandbox"
infra_diagnostic_log_storage_account_id = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT_NAME>"

# event hubs
event_hub_subnet_ids = "[\"/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Network/virtualNetworks/VNET_NAME/subnets/<SUBNET_NAME>\",\"/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Network/virtualNetworks/VNET_NAME/subnets/<SUBNET_NAME>\"]"

# pipeline virtual machine
pipeline_custom_image_id = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Compute/images/<IMAGE_NAME>"
pipeline_user_identities = ["/subscriptions/<SUBSCRIPTION_ID>/resourcegroups/<RG_NAME>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<USER_ASSIGNED_IDENTITY>"]

# visualization virtual machine
visualization_custom_image_id = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Compute/images/<IMAGE_NAME>"
visualization_user_identities = ["/subscriptions/<SUBSCRIPTION_ID>/resourcegroups/<RG_NAME>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<USER_ASSIGNED_IDENTITY>"]

grafana_aad_client_id = "<CLIENT_ID>"
grafana_aad_client_secret_keyvault_secret_id="<KV_SECRET_ID>"
grafana_aad_directory_id = "<DIRECTORY_ID>"
grafana_root_url = "https://vm-12345.westus2.cloudapp.azure.com"

# keyvault
key_vault_id = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.KeyVault/vaults/<KEYVAULT_NAME>"