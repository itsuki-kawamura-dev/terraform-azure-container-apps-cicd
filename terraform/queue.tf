resource "azurerm_servicebus_namespace" "main" {
  name                = "sbns-container-apps-lab"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "jobs" {
  name         = "jobs"
  namespace_id = azurerm_servicebus_namespace.main.id
}