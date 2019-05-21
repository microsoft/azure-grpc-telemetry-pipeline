resource "azurerm_storage_account" "capture" {
    name = "${lower(local.baseName)}",
    resource_group_name = "${azurerm_resource_group.rg.name}"
    location = "${azurerm_resource_group.rg.location}"
    account_tier = "Standard"
    account_replication_type = "LRS"
    enable_blob_encryption = true
    enable_https_traffic_only = true
    network_rules {
        bypass = ["AzureServices"]
    }
}