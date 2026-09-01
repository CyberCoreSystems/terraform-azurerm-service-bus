output "namespace_id" {
  description = "Service Bus namespace resource ID."
  value       = module.service_bus.id
}

output "namespace_endpoint" {
  description = "Service Bus namespace endpoint URL."
  value       = module.service_bus.endpoint
}

output "queue_ids" {
  description = "Map of queue name => queue resource ID."
  value       = module.service_bus.queue_ids
}

output "subscription_ids" {
  description = "Map of topic/subscription => subscription resource ID."
  value       = module.service_bus.subscription_ids
}
