output "id" {
  description = "The Service Bus namespace resource ID."
  value       = azurerm_servicebus_namespace.this.id
}

output "name" {
  description = "The Service Bus namespace name."
  value       = azurerm_servicebus_namespace.this.name
}

output "endpoint" {
  description = "The namespace endpoint URL (e.g. https://<name>.servicebus.windows.net:443/)."
  value       = azurerm_servicebus_namespace.this.endpoint
}

output "system_assigned_identity_principal_id" {
  description = "Principal ID of the namespace's system-assigned managed identity (null when not enabled)."
  value       = one(azurerm_servicebus_namespace.this.identity[*].principal_id)
}

output "queue_ids" {
  description = "Map of queue name => queue resource ID."
  value       = { for key, queue in azurerm_servicebus_queue.this : key => queue.id }
}

output "topic_ids" {
  description = "Map of topic name => topic resource ID."
  value       = { for key, topic in azurerm_servicebus_topic.this : key => topic.id }
}

output "subscription_ids" {
  description = "Map of \"topic/subscription\" => subscription resource ID."
  value       = { for key, sub in azurerm_servicebus_subscription.this : key => sub.id }
}
