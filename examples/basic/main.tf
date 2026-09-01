provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "service_bus" {
  source = "../.."

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"

  queues = {
    orders = {
      max_delivery_count                   = 10
      dead_lettering_on_message_expiration = true
    }
  }

  topics = {
    events = {
      support_ordering = true
      subscriptions = {
        all = {
          max_delivery_count = 10
        }
        audit = {
          max_delivery_count = 5
        }
      }
    }
  }

  tags = {
    environment = "example"
    managed_by  = "iac-bazaar"
  }
}
