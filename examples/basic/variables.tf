variable "subscription_id" {
  description = "Target Azure subscription GUID. Leave null to take it from ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
}

variable "name" {
  description = "Service Bus namespace name (globally unique)."
  type        = string
  default     = "sb-iacbazaar-example-001"
}

variable "resource_group_name" {
  description = "Existing resource group to deploy into."
  type        = string
  default     = "rg-servicebus-example"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}
