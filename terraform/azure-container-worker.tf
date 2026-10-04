resource "azurerm_user_assigned_identity" "worker" {
  name                = "id-container-worker"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "servicebus_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}
resource "azurerm_role_assignment" "worker_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}
resource "azurerm_role_assignment" "worker_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

resource "azurerm_container_app" "worker" {
  name                         = "ca-azure-worker"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.worker.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.worker.id
  }

  template {
    container {
      name   = "worker"
      image  = "${azurerm_container_registry.main.login_server}/azure-worker:v2"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.worker.client_id
      }
    }

    min_replicas = 0
    max_replicas = 3
    custom_scale_rule {
      name             = "servicebus-queue"
      custom_rule_type = "azure-servicebus"

      metadata = {
        queueName    = "jobs"
        namespace    = "sbns-container-apps-lab"
        messageCount = "5"
      }

      # Managed Identityで認証
      identity_id = azurerm_user_assigned_identity.worker.id
    }
  }

  depends_on = [
    azurerm_role_assignment.servicebus_receiver,
    azurerm_role_assignment.worker_acr_pull
  ]
}