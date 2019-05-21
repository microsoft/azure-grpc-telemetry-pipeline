# This is an example vars file for deploying the streaming telemetry sample

# The name of the resource group to deploy the sample into
resource_group_name = "network-telemetry-pipeline"

# The location for the resources
location = "westus2"

# Virtual machines are deployed into a preexisting subnet that needs connectivity from your IOS-XR devices
# The Azure resource ID of the subnet
infra_sandbox_subnet_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.Network/virtualNetworks/my-vnet/sandbox"

# Diagnostic logs are saved in a storage account for later processing
# The Azure resource ID of the storage account that should be used for logs
infra_diagnostic_log_storage_account_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.Storage/storageAccounts/networktelemetrylogs"

# The Event Hub namespace is configured to restrict access only to specific subnets
# An array of Azure resource ID's to which the Event Hub namespace should allow connections
event_hub_subnet_ids = "[\"/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/sandbox\"]"

# The Azure resource ID of a VM images to deploy as the pipeline and visualization VMs
# This is created as a result of the `packer pipeline.json` command
pipeline_custom_image_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/vm-images/providers/Microsoft.Compute/images/pipeline-2019-05-20T21-36-19Z"

# This is created as a result of the `packer visualization.json` command
visualization_custom_image_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/vm-images/providers/Microsoft.Compute/images/visualization-2019-05-20T21-43-27Z"

# The sample uses User-Assigned Identity to retrieve secrets from Key Vault rather than storing secrets on disk
# The Azure resource ID of the User-Assigned Identity to be used by the pipeline VM to retrieve secrets from Key Vault
pipeline_user_identities = ["/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourcegroups/network-telemetry-infra/providers/Microsoft.ManagedIdentity/userAssignedIdentities/pipeline_identity"]

# The Azure resource ID of the User-Assigned Identity to be used by the visualization VM to retrieve secrets from Key Vault
visualization_user_identities = ["/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourcegroups/network-telemetry-infra/providers/Microsoft.ManagedIdentity/userAssignedIdentities/visualization_identity"]

# Grafana integration with Azure Active Directory logins requires an Application registration
# The client_id for the Application
grafana_aad_client_id = "d0c05ba1-f246-41b6-8fb2-931446506d32"

# The tenant_id for the Application
grafana_aad_directory_id = "9750d6f0-3d23-4eb7-a93d-a73e69fc3f69"

# The sample assumes that your Application client_secret is stored securely as a Key Vault secret
# This is the ID of the Key Vault secret that the value is stored in, and be found in the output of the `az keyvault set` command
grafana_aad_client_secret_keyvault_secret_id="https://myvault.vault.azure.net/secrets/grafana/7fb2298f55194e289e26a65ea34fb2f3"

# Grafana will include its root_url in AAD authentication requests. The root_url needs to match a DNS entry that will points to the visualization VM
grafana_root_url = "https://vm-12345.westus2.cloudapp.azure.com"

# The Azure resource ID of the Key Vault to be used for storing secrets
key_vault_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.KeyVault/vaults/myvault"