terraform {
    backend "azurerm" {
        container_name = "terraform"
        key = "azure.terraform.tfstate"
    }
}

provider "azurerm" {
  version = "~>1.24"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"
}


