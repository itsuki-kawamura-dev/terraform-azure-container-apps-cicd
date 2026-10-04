resource "azurerm_container_registry" "main" {
  name                = "acritsukicontainerlab"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_user_assigned_identity" "container_app" {
  name                = "id-container-app"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}
resource "azurerm_role_assignment" "servicebus_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-container-apps-lab"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-container-apps-lab"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}
resource "azurerm_container_app" "api" {
  name                         = "ca-azure-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  template {
    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/azure-api:v5"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.container_app.client_id
      }
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull
  ]
}
lifecycle {
  ignore_changes = [
    template[0].container[0].image
  ]
}