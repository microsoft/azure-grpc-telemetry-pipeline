# azure-grpc-telemetry-pipeline

This repository contains a sample implementation of a data pipeline to ingest streaming telemetry from Cisco IOS XR devices and process the data on Azure.

# Overview

Some modern enterprise routers have the ability to stream telemetry in real-time rather than relying on traditional poll-based monitoring strategies. These devices are often deployed into environments with requirements around automated and immutable infrastructure. This is a sample implementation that combines these ideas to process streaming telemetry on Azure.

# Deployment

The sample utilizes widely-used OSS tools for deployments. Ansible is used to configure virtual machines. Packer is used to automate creation and capture of VM images. Terraform is used for deployment of Azure resources.

Required tools:

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Ansible](https://www.ansible.com/)
* [Packer](https://https://www.packer.io/)
* [Terraform](https://www.terraform.io/)

## Prerequisites

The sample makes several assumptions regarding your existing on-premises and Azure infrastructure. These core resources are often managed by separate teams, so are left separate from the sample data pipeline.

* IOS-XR devices are in existing on-premises subnet(s) that have connectivity to Azure via ExpressRoute or VPN Gateway
* Existing VNET in which you wish to deploy the sample components into
* User-assigned identities for the `pipeline` and `visualization` VMs
* Key Vault for storing secrets
* Storage account for capturing diagnostic logs
* Azure Active Directory application to enable AAD sign-on with Grafana

> As a reference, we've provided some sample infrastructure components for development/reference under `terraform/infra`. You can find more details in the [Development](#Development) section below

## Authenticating

The sample has been tested with a Service Principal with `Contributor` over the target subscription. Secrets are consumed as environment variables.

```shell
# Create a service principal with the Contributor role
az ad sp create-for-rbac

# Set environment variables for auth
export ARM_CLIENT_ID=<appId>
export ARM_CLIENT_SECRET=<password>
export ARM_TENANT_ID=<tenant>
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## Creating VM images

We use Packer with the Ansible provisioner to capture RHEL-based VM images. For some components, you may wish to pull a specific version or a custom build. To do so, change the `*_DOWNLOAD_URL` variables to point to your desired binary.

```shell
# Set environment variables for Packer
export PACKER_IMAGE_RESOURCE_GROUP=vm-images
export PACKER_IMAGE_LOCATION=westus2

# Create a resource group to hold captured images
az group create -n $PACKER_IMAGE_RESOURCE_GROUP -l $PACKER_IMAGE_LOCATION

# Build the pipeline VM image
export PACKER_PIPELINE_DOWNLOAD_URL='https://github.com/cisco-ie/pipeline-gnmi/raw/master/bin/pipeline'
packer build packer/pipelne.json

# Build the visualization VM image
export PACKER_PIPELINE_DOWNLOAD_URL='https://github.com/noelbundick/pipeline-gnmi/releases/download/custom-build-1/pipeline'
export PACKER_INFLUX_DOWNLOAD_URL='https://dl.influxdata.com/influxdb/releases/influxdb-1.7.6.x86_64.rpm'
export PACKER_GRAFANA_DOWNLOAD_URL='https://dl.grafana.com/oss/release/grafana-6.1.6-1.x86_64.rpm'
packer build packer/visualization.json
```

## Deploying resources via Terraform

We use Terraform to deploy Azure resources

First, create a file named `terraform.tfvars`, and fill it using the content from `sample.tfvars` and the values for your own environment. Here's an example of what a concrete config might look like:

```ini
resource_group_name = "network-telemetry-pipeline"
location = "westus2"
infra_sandbox_subnet_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.Network/virtualNetworks/my-vnet/sandbox"
infra_diagnostic_log_storage_account_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.Storage/storageAccounts/networktelemetrylogs"
event_hub_subnet_ids = "[\"/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/sandbox\"]"
pipeline_custom_image_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/vm-images/providers/Microsoft.Compute/images/pipeline-2019-05-20T21-36-19Z"
pipeline_user_identities = ["/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourcegroups/network-telemetry-infra/providers/Microsoft.ManagedIdentity/userAssignedIdentities/pipeline_identity"]
visualization_custom_image_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/vm-images/providers/Microsoft.Compute/images/visualization-2019-05-20T21-43-27Z"
visualization_user_identities = ["/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourcegroups/network-telemetry-infra/providers/Microsoft.ManagedIdentity/userAssignedIdentities/visualization_identity"]
grafana_aad_client_id = "d0c05ba1-f246-41b6-8fb2-931446506d32"
grafana_aad_client_secret_keyvault_secret_id="https://myvault.vault.azure.net/secrets/grafana/7fb2298f55194e289e26a65ea34fb2f3"
grafana_aad_directory_id = "9750d6f0-3d23-4eb7-a93d-a73e69fc3f69"
grafana_root_url = "https://vm-12345.westus2.cloudapp.azure.com"    # note: this DNS entry will need to point to your visualization VM
key_vault_id = "/subscriptions/270bcfc0-0300-45e9-a214-eb41d7795a90/resourceGroups/network-telemetry-infra/providers/Microsoft.KeyVault/vaults/myvault"
```

Next, use Terraform to deploy into Azure:

```shell
# Specify/create the storage account used for the Terraform backend
TF_BACKEND_RG=terraform-backend
TF_BACKEND_STORAGE=tfbackend
az group create -n $TF_BACKEND_RG -l westus2
az storage account create -g $TF_BACKEND_RG -n $TF_BACKEND_STORAGE --sku Standard_LRS

cd terraform/azure
terraform init \
  --backend-config="storage_account_name=$TF_BACKEND_STORAGE" \
  --backend-config="resource_group_name=$TF_BACKEND_RG" \
  --backend-config="key=azure.terraform.tfstate"

terraform apply
```

## Grafana configuration

You'll need to perform a couple of quick steps to configure Grafana.

First, visit your visualization VM's IP address, and login with `admin`/`admin`, and change it to something more secure.

Next, add a data source with the following settings

* Type: `InfluxDB`
* Url: `http://localhost:8086`
* Database: `telemetry`

### (Optional) DNS for Grafana AAD integration

To finish configuring AAD integration with Grafana, you will need to ensure that you have a DNS entry for the `grafana_root_url` that points to the IP address of your visualization VM. This can be a hostfile entry or a normal DNS record.


# Usage

## Configure your IOS-XR router

You'll need to configure sensors and settings on your device(s) to send data from your IOS-XR router to your `pipeline` VM IP address. Configuring sensors and telemetry options on your router is out of the scope of this README. You can find more info on how to enable streaming telemetry from the router side on [xrdocs.io](https://xrdocs.io/telemetry/).


## Create graphs

Once you've got data flowing into the system, it will land in InfluxDB and be available for visualization. 

## Azure Diagnostic Logs 
When we turn on Diagnostic Logs for a service they will be plumbed into a storage account. Logs are stored in files per hour and follow the blob naming convention below. Additional details can be found on the [archive-diagnostic-logs documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/archive-diagnostic-logs#schema-of-diagnostic-logs-in-the-storage-account) page.

```
insights-logs-{log category name}/resourceId=/SUBSCRIPTIONS/{subscription ID}/RESOURCEGROUPS/{resource group name}/PROVIDERS/{resource provider name}/{resource type}/{resource name}/y={four-digit numeric year}/m={two-digit numeric month}/d={two-digit numeric day}/h={two-digit 24-hour clock hour}/m=00/PT1H.json
```

## Application Logs

Most systems aggregate and ship logs to a central system. While configuring your system of choice is outside of scope of this sample, the application log paths are listed below so enable you to quickly collect them:

* Pipeline
  * pipeline: `/etc/pipeline/pipeline.log`
* Visualization
  * pipeline: `/etc/pipelne/pipeline.log`
  * InfluxDB: via the `systemd` journal - `journalctl -u influxdb.service`
  * Grafana: `/var/log/grafana/grafana.log`

# Development

The sample assumes you'll have your own network configuration and will deploy into your existing VNETs/subnets. To help with dev/test, we've provided a Terraform configuration that deploys everything needed to get up and running quickly.

To use it, follow the [Deployment](#Deployment) instructions up to the Terraform deployment, and deploy the development infra before running `terraform apply`

```shell
# Specify/create the storage account used for the Terraform backend
TF_BACKEND_RG=terraform-backend
TF_BACKEND_STORAGE=tfbackend
az group create -n $TF_BACKEND_RG -l westus2
az storage account create -g $TF_BACKEND_RG -n $TF_BACKEND_STORAGE --sku Standard_LRS

# Deploy the development infrastructure
cd terraform/infra
terraform init \
  --backend-config="storage_account_name=$TF_BACKEND_STORAGE" \
  --backend-config="resource_group_name=$TF_BACKEND_RG" \
  --backend-config="key=infra.terraform.tfstate"

terraform apply \
  -var 'infra_resource_group_name=network-telemetry-infra' \
  -var 'grafana_aad_client_secret=5554eb17-abf0-4c59-aac4-f4a7405ec53d'
```

## Troubleshooting

## Accessing Azure VM 
First, we need to create a public ip address and assign it the nic attached to the VM.

```shell
RESOURCE_GROUP_NAME=azure-pipeline-rg
az network public-ip create -g $RESOURCE_GROUP_NAME --name publicip1 --allocation-method Static
az network nic ip-config create -g $RESOURCE_GROUP_NAME --nic-name '<<NIC_NAME>>' --name testconfiguration1 --public-ip-address publicip1
```

Finally, we can set the SSH keys so that we can SSH into the vm.

```shell
az vm user update \
  --resource-group $RESOURCE_GROUP_NAME \
  --name <<VM_NAME>> \
  --username azureuser \
  --ssh-key-value ~/.ssh/id_rsa.pub
```


# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.