terraform {
    backend "azurerm" {
        container_name = "terraform"
        key = "infra.terraform.tfstate"
    }
}

provider "azurerm" {
  version = "~>1.24"
}