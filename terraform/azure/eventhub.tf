locals {
  event_hub_namespace = "eh-${local.baseName}"
}

resource "azurerm_eventhub_namespace" "kafka" {
  name = "${local.event_hub_namespace}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
  sku = "Standard"
  capacity = 1
  kafka_enabled = true
}

resource "azurerm_eventhub" "telemetry" {
  name = "telemetry"
  namespace_name = "${azurerm_eventhub_namespace.kafka.name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  message_retention = "${var.message_retention_in_days}"
  partition_count = "${var.partition_count}"

  capture_description {
    enabled = true
    skip_empty_archives = true
    encoding = "Avro"
    interval_in_seconds = 60
    size_limit_in_bytes = 10485760
    destination {
      name = "EventHubArchive.AzureBlockBlob"
      storage_account_id = "${azurerm_storage_account.capture.id}"
      blob_container_name = "telemetry"
      archive_name_format = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"
    }
  }
}

resource "azurerm_eventhub" "binary" {
  name = "binary"
  namespace_name = "${azurerm_eventhub_namespace.kafka.name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  message_retention = "${var.message_retention_in_days}"
  partition_count = "${var.partition_count}"
}

resource "azurerm_eventhub_consumer_group" "metrics" {
  name                = "metrics"
  namespace_name      = "${azurerm_eventhub_namespace.kafka.name}"
  eventhub_name       = "${azurerm_eventhub.binary.name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_template_deployment" "eventhub_vnet_rules" {
  depends_on          = ["azurerm_eventhub_namespace.kafka"]
  name                = "eventhub_vnet_rules"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  template_body = <<DEPLOY
  {
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "ehNamespace": {
        "type": "string"
      },
      "subnetIds": {
        "type": "array",
        "defaultValue": ${var.event_hub_subnet_ids}
      }
    },
    "variables": {},
    "resources": [
      {
        "copy": {
          "name": "networkRuleCopy",
          "count": "[length(parameters('subnetIds'))]"
        },
        "apiVersion": "2018-01-01-preview",
        "type": "Microsoft.EventHub/namespaces/virtualnetworkrules",
        "name": "[concat(parameters('ehNamespace'), '/vnet-', copyIndex())]",
        "properties": {
          "virtualNetworkSubnetId": "[parameters('subnetIds')[copyIndex()]]"
        }
      }
    ],
    "outputs": {}
  }

DEPLOY

  # these key-value pairs are passed into the ARM Template's `parameters` block
  parameters = {
    "ehNamespace" = "${local.event_hub_namespace}"
  }

  deployment_mode = "Incremental"
}

resource "azurerm_eventhub_namespace_authorization_rule" "writer_pipeline" {
  name = "pipeline"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  namespace_name = "${azurerm_eventhub_namespace.kafka.name}"
  listen = false
  send = true
  manage = false
}

resource "azurerm_eventhub_namespace_authorization_rule" "reader_metrics" {
  name = "metrics"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  namespace_name = "${azurerm_eventhub_namespace.kafka.name}"
  listen = true
  send = false
  manage = false
}

resource "azurerm_key_vault_secret" "writer_pipeline" {
  name     = "eh-pipeline"
  value    = "${azurerm_eventhub_namespace_authorization_rule.writer_pipeline.primary_connection_string}"
  key_vault_id = "${var.key_vault_id}"
}

resource "azurerm_key_vault_secret" "reader_metrics" {
  name     = "eh-metrics"
  value    = "${azurerm_eventhub_namespace_authorization_rule.reader_metrics.primary_connection_string}"
  key_vault_id = "${var.key_vault_id}"
}

resource "azurerm_monitor_diagnostic_setting" "diagnostic_logs" {
  name               = "diagnostic-logs-pipeline"
  target_resource_id = "${azurerm_eventhub_namespace.kafka.id}"
  storage_account_id = "${var.infra_diagnostic_log_storage_account_id}"

  log {
    category = "ArchiveLogs"

    retention_policy {
      enabled = true
      days = 7
    }
  }

  log {
    category = "OperationalLogs"

    retention_policy {
      enabled = true
      days = 7
    }
  }

  log {
    category = "AutoScaleLogs"

    retention_policy {
      enabled = true
      days = 7
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days = 7
    }
  }
}