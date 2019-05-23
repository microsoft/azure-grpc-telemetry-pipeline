# azure-grpc-telemetry-pipeline

This repository contains a sample implementation of a data pipeline to ingest streaming telemetry from Cisco IOS XR devices and process the data on Azure.

# Overview

Some modern enterprise routers have the ability to stream telemetry in real-time rather than relying on traditional poll-based monitoring strategies. These devices are often deployed into environments with requirements around automated and immutable infrastructure. This is a sample implementation that combines these ideas to process streaming telemetry on Azure.

# Deployment

The sample utilizes widely-used OSS tools for deployments. Ansible is used to configure virtual machines. Packer is used to automate creation and capture of VM images. Terraform is used for deployment of Azure resources.

Required tools w/ validated versions:

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) `2.0.65`
* [Ansible](https://www.ansible.com/) `2.8.0`
* [Packer](https://www.packer.io/) `1.4.1`
* [Terraform](https://www.terraform.io/) `0.11.13`

All deployment commands should be run in a Bash terminal

## Prerequisites

The sample makes several assumptions regarding your existing on-premises and Azure infrastructure. These core resources are often managed by separate teams, so are left separate from the sample data pipeline.

* IOS-XR devices are in existing on-premises subnet(s) that have connectivity to Azure via ExpressRoute or VPN Gateway
* Existing VNET in which you wish to deploy the sample components into
* User-assigned identities for the `pipeline` and `visualization` VMs
* Key Vault for storing secrets
* Storage account for capturing diagnostic logs
* Azure Active Directory application to enable AAD sign-on with Grafana

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

## Development infrastructure

If you don't have an existing environment, or if you want to create an environment to contribute to the sample itself, you can use the following steps to create one.

```shell
# Specify/create the storage account used for the Terraform backend
TF_BACKEND_RG=terraform-backend
TF_BACKEND_STORAGE=tfbackend
az group create -n $TF_BACKEND_RG -l westus2
az storage account create -g $TF_BACKEND_RG -n $TF_BACKEND_STORAGE --sku Standard_LRS
az storage container create -n terraform --account-name $TF_BACKEND_STORAGE

# GRAFANA_ROOT_URL should be a DNS name that will resolve to a visualization VM that is created later
# This can be an actual DNS entry or a hostfile entry
GRAFANA_ROOT_URL='https://vm-12345.westus2.cloudapp.azure.com'

# Create an AAD Application for use with Grafana
CLIENT_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
az ad app create \
  --display-name grafana \
  --reply-urls "https://$GRAFANA_ROOT_URL/login/generic_oauth" \
  --key-type Password
  --password $CLIENT_SECRET

# Deploy the development infrastructure
cd terraform/infra
terraform init \
  --backend-config="storage_account_name=$TF_BACKEND_STORAGE" \
  --backend-config="resource_group_name=$TF_BACKEND_RG" \
  --backend-config="key=infra.terraform.tfstate"

terraform apply \
  -var "infra_resource_group_name=network-telemetry-infra" \
  -var "grafana_aad_client_secret=$CLIENT_SECRET"
```


## Creating VM images

We use Packer with the Ansible provisioner to capture RHEL-based VM images. For some components, you may wish to pull a specific version or a custom build. To do so, change the `*_DOWNLOAD_URL` variables to point to your desired binary.

```shell
# Switch to the Packer directory so that relative paths correctly resolve
cd packer

# Set environment variables for Packer
export PACKER_IMAGE_RESOURCE_GROUP=vm-images
export PACKER_IMAGE_LOCATION=westus2

# Create a resource group to hold captured images
az group create -n $PACKER_IMAGE_RESOURCE_GROUP -l $PACKER_IMAGE_LOCATION

# Build the pipeline VM image
export PACKER_PIPELINE_DOWNLOAD_URL='https://github.com/cisco-ie/pipeline-gnmi/raw/master/bin/pipeline'
packer build pipeline.json

# Build the visualization VM image
export PACKER_PIPELINE_DOWNLOAD_URL='https://github.com/noelbundick/pipeline-gnmi/releases/download/custom-build-1/pipeline'
export PACKER_INFLUX_DOWNLOAD_URL='https://dl.influxdata.com/influxdb/releases/influxdb-1.7.6.x86_64.rpm'
export PACKER_GRAFANA_DOWNLOAD_URL='https://dl.grafana.com/oss/release/grafana-6.1.6-1.x86_64.rpm'
packer build visualization.json
```

## Deploying resources via Terraform

We use Terraform to deploy Azure resources

Create a file named `terraform.tfvars`, and fill it using the content from [`terraform/azure/sample.tfvars`](terraform/azure/sample.tfvars) and the values for your own environment. `sample.tfvars` contains additional annotations for each required variable and where to find their values.

Next, use Terraform to deploy into Azure:

```shell
# Specify/create the storage account used for the Terraform backend
TF_BACKEND_RG=terraform-backend
TF_BACKEND_STORAGE=tfbackend
az group create -n $TF_BACKEND_RG -l westus2
az storage account create -g $TF_BACKEND_RG -n $TF_BACKEND_STORAGE --sku Standard_LRS
az storage container create -n terraform --account-name $TF_BACKEND_STORAGE

cd terraform/azure
terraform init \
  --backend-config="storage_account_name=$TF_BACKEND_STORAGE" \
  --backend-config="resource_group_name=$TF_BACKEND_RG" \
  --backend-config="key=azure.terraform.tfstate"

terraform apply
```

> Note: all components are deployed inside a VNET and are inaccessible to the outside world. If you want to access your resources from the Internet, you'll need to make some changes. [Public access to VMs](#Public-access-to-VMs) has additional details.

## Grafana configuration

You'll need to perform a couple of quick steps to configure Grafana.

First, visit your visualization VM's IP address in a web browser, and login with `admin`/`admin`, then change it to something more secure.

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



# Troubleshooting

## Public access to VMs

For development or troubleshooting, it can be useful to expose VMs to the Internet so you can stream telemetry, SSH and investigate issues, etc. Use the following steps to add a public IP and add your SSH key to the VM.

```shell
RESOURCE_GROUP=network-telemetry-pipeline

# You can find the name of your created VMs by visiting the Portal or by running `az vm list -g $RESOURCE_GROUP -o table`
VM_NAME=viz-c7dd9e3cfc44

# Add a public IP to a VM
az network public-ip create -g $RESOURCE_GROUP --name publicip1 --allocation-method Static
NIC_ID=$(az vm show -n $VM_NAME -g $RESOURCE_GROUP --query 'networkProfile.networkInterfaces[0].id' -o tsv)
az network nic ip-config update -g $RESOURCE_GROUP --nic-name "${NIC_ID##*/}" --name config1 --public-ip-address=publicip1

# Add your SSH key to the VM
az vm user update \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
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