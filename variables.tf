variable "name" {
  description = "Service Bus namespace name. Globally unique, 6-50 chars, must start with a letter, end with a letter or digit, and contain only letters, digits and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{4,48}[a-zA-Z0-9]$", var.name))
    error_message = "name must be 6-50 chars, start with a letter, end with a letter or digit, and contain only letters, digits and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of an existing resource group to create the namespace in."
  type        = string
}

variable "location" {
  description = "Azure region for the namespace."
  type        = string
}

variable "sku" {
  description = "Namespace SKU. Basic has queues only (NO topics/subscriptions); Standard adds topics/subscriptions; Premium adds dedicated capacity, CMK and private endpoints."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard or Premium."
  }
}

variable "capacity" {
  description = "Premium messaging units (ignored unless sku = Premium). One of 1, 2, 4, 8, 16."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2, 4, 8, 16], var.capacity)
    error_message = "capacity must be one of 1, 2, 4, 8, 16 (only applied when sku = Premium)."
  }
}

variable "premium_messaging_partitions" {
  description = "Number of messaging partitions for a Premium namespace (ignored unless sku = Premium). One of 0, 1, 2, 4."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 2, 4], var.premium_messaging_partitions)
    error_message = "premium_messaging_partitions must be one of 0, 1, 2, 4 (only applied when sku = Premium)."
  }
}

variable "local_auth_enabled" {
  description = "Allow SAS (shared access signature) authentication. Off by default: use Microsoft Entra ID + Azure RBAC. Control-plane management (creating queues/topics) works regardless; this only governs data-plane SAS keys."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow access over the public endpoint. Restricting this to private-endpoint-only requires the Premium SKU."
  type        = bool
  default     = true
}

variable "minimum_tls_version" {
  description = "Minimum TLS version accepted by the namespace."
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.0", "1.1", "1.2"], var.minimum_tls_version)
    error_message = "minimum_tls_version must be 1.0, 1.1 or 1.2."
  }
}

variable "system_assigned_identity_enabled" {
  description = "Create a system-assigned managed identity on the namespace (opt-in; used for customer-managed-key encryption on Premium and other Entra-authenticated integrations)."
  type        = bool
  default     = false
}

variable "user_assigned_identity_ids" {
  description = "User-assigned managed identity IDs to attach to the namespace."
  type        = list(string)
  default     = []
}

variable "customer_managed_key" {
  description = "Customer-managed key (CMK) encryption for the namespace — Premium SKU only. identity_id is a user-assigned managed identity with get/wrapKey/unwrapKey rights on the Key Vault key; it is attached to the namespace automatically. infrastructure_encryption_enabled adds a second (infrastructure-layer) encryption pass. Default null = Microsoft-managed keys."
  type = object({
    key_vault_key_id                  = string
    identity_id                       = string
    infrastructure_encryption_enabled = optional(bool, true)
  })
  default = null
}

variable "queues" {
  description = "Service Bus queues keyed by queue name. Secure/operational defaults: dead-letter expired messages, 10 deliveries before dead-lettering."
  type = map(object({
    lock_duration                           = optional(string, "PT1M")
    max_size_in_megabytes                   = optional(number, 1024)
    max_delivery_count                      = optional(number, 10)
    requires_session                        = optional(bool, false)
    requires_duplicate_detection            = optional(bool, false)
    duplicate_detection_history_time_window = optional(string, "PT10M")
    default_message_ttl                     = optional(string)
    auto_delete_on_idle                     = optional(string)
    dead_lettering_on_message_expiration    = optional(bool, true)
    batched_operations_enabled              = optional(bool, true)
    express_enabled                         = optional(bool, false)
    partitioning_enabled                    = optional(bool, false)
    forward_to                              = optional(string)
    forward_dead_lettered_messages_to       = optional(string)
    max_message_size_in_kilobytes           = optional(number)
    status                                  = optional(string, "Active")
  }))
  default = {}

  validation {
    condition     = alltrue([for queue in values(var.queues) : queue.max_delivery_count >= 1 && queue.max_delivery_count <= 2000])
    error_message = "queues max_delivery_count must be between 1 and 2000."
  }

  validation {
    condition     = alltrue([for queue in values(var.queues) : contains(["Active", "Disabled", "SendDisabled", "ReceiveDisabled"], queue.status)])
    error_message = "queues status must be Active, Disabled, SendDisabled or ReceiveDisabled."
  }
}

variable "topics" {
  description = "Service Bus topics keyed by topic name, each with its own subscriptions map. Requires sku = Standard or Premium."
  type = map(object({
    max_size_in_megabytes                   = optional(number, 1024)
    requires_duplicate_detection            = optional(bool, false)
    duplicate_detection_history_time_window = optional(string, "PT10M")
    default_message_ttl                     = optional(string)
    auto_delete_on_idle                     = optional(string)
    batched_operations_enabled              = optional(bool, true)
    express_enabled                         = optional(bool, false)
    partitioning_enabled                    = optional(bool, false)
    support_ordering                        = optional(bool, false)
    max_message_size_in_kilobytes           = optional(number)
    status                                  = optional(string, "Active")
    subscriptions = optional(map(object({
      max_delivery_count                        = optional(number, 10)
      lock_duration                             = optional(string, "PT1M")
      requires_session                          = optional(bool, false)
      default_message_ttl                       = optional(string)
      auto_delete_on_idle                       = optional(string)
      dead_lettering_on_message_expiration      = optional(bool, true)
      dead_lettering_on_filter_evaluation_error = optional(bool, true)
      batched_operations_enabled                = optional(bool, true)
      forward_to                                = optional(string)
      forward_dead_lettered_messages_to         = optional(string)
      status                                    = optional(string, "Active")
    })), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for topic in values(var.topics) : contains(["Active", "Disabled", "SendDisabled", "ReceiveDisabled"], topic.status)])
    error_message = "topics status must be Active, Disabled, SendDisabled or ReceiveDisabled."
  }

  validation {
    condition = alltrue(flatten([
      for topic in values(var.topics) : [
        for sub in values(topic.subscriptions) : sub.max_delivery_count >= 1 && sub.max_delivery_count <= 2000
      ]
    ]))
    error_message = "subscriptions max_delivery_count must be between 1 and 2000."
  }
}

variable "tags" {
  description = "Tags applied to the namespace (Service Bus entities do not support tags)."
  type        = map(string)
  default     = {}
}
