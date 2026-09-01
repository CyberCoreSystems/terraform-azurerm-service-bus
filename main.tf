# Secure-by-default Azure Service Bus: a namespace (Standard by default so
# topics work — Basic has none) with SAS local auth OFF (Entra ID + RBAC),
# TLS 1.2+ minimum, plus queues, topics and topic subscriptions driven by
# clean for_each maps. Queues/subscriptions dead-letter expired messages by
# default. Premium-only knobs (capacity, partitions, large messages) are gated
# so a Standard namespace plans cleanly.

locals {
  # A CMK's user-assigned identity must also be attached to the namespace, so
  # merge it into the identity list automatically.
  cmk_identity_ids = var.customer_managed_key == null ? [] : [var.customer_managed_key.identity_id]
  all_identity_ids = distinct(concat(var.user_assigned_identity_ids, local.cmk_identity_ids))

  identity_type = (
    var.system_assigned_identity_enabled && length(local.all_identity_ids) > 0 ? "SystemAssigned, UserAssigned" :
    var.system_assigned_identity_enabled ? "SystemAssigned" :
    length(local.all_identity_ids) > 0 ? "UserAssigned" :
    null
  )

  # Flatten topic -> subscriptions into a single map keyed "topic/subscription"
  # for a stable for_each over non-computed keys.
  subscriptions = merge([
    for topic_name, topic in var.topics : {
      for sub_name, sub in topic.subscriptions :
      "${topic_name}/${sub_name}" => merge(sub, {
        topic_key = topic_name
        sub_name  = sub_name
      })
    }
  ]...)
}

resource "azurerm_servicebus_namespace" "this" {
  # checkov:skip=CKV_AZURE_201: CMK is an explicit buyer knob via var.customer_managed_key (Premium-SKU-only feature; default null = Microsoft-managed keys)
  # checkov:skip=CKV_AZURE_199: infrastructure (double) encryption rides the CMK buyer knob — customer_managed_key.infrastructure_encryption_enabled defaults to true when CMK is set (Premium SKU only)
  # checkov:skip=CKV_AZURE_204: public access is a deliberate buyer knob via var.public_network_access_enabled; private-endpoint-only access requires the Premium SKU (the default Standard SKU has no private path)
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  # Premium-only sizing — forced to 0 on Basic/Standard so the API accepts it.
  capacity                     = var.sku == "Premium" ? var.capacity : 0
  premium_messaging_partitions = var.sku == "Premium" ? var.premium_messaging_partitions : 0

  local_auth_enabled            = var.local_auth_enabled
  public_network_access_enabled = var.public_network_access_enabled
  minimum_tls_version           = var.minimum_tls_version

  dynamic "identity" {
    for_each = local.identity_type == null ? [] : [1]
    content {
      type         = local.identity_type
      identity_ids = local.all_identity_ids
    }
  }

  # Customer-managed key encryption (Premium only). The referenced user-assigned
  # identity is attached to the namespace automatically and must already hold
  # get/wrapKey/unwrapKey rights on the Key Vault key.
  dynamic "customer_managed_key" {
    for_each = var.customer_managed_key == null ? [] : [var.customer_managed_key]
    content {
      key_vault_key_id                  = customer_managed_key.value.key_vault_key_id
      identity_id                       = customer_managed_key.value.identity_id
      infrastructure_encryption_enabled = customer_managed_key.value.infrastructure_encryption_enabled
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.sku != "Basic" || length(var.topics) == 0
      error_message = "Basic SKU does not support topics/subscriptions; use Standard or Premium."
    }

    precondition {
      condition = var.sku == "Premium" || (
        alltrue([for queue in values(var.queues) : queue.max_message_size_in_kilobytes == null]) &&
        alltrue([for topic in values(var.topics) : topic.max_message_size_in_kilobytes == null])
      )
      error_message = "max_message_size_in_kilobytes is only supported on the Premium SKU."
    }

    precondition {
      condition     = var.customer_managed_key == null || var.sku == "Premium"
      error_message = "customer_managed_key (CMK encryption) requires the Premium SKU."
    }
  }
}

resource "azurerm_servicebus_queue" "this" {
  for_each = var.queues

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this.id

  lock_duration                           = each.value.lock_duration
  max_size_in_megabytes                   = each.value.max_size_in_megabytes
  max_delivery_count                      = each.value.max_delivery_count
  requires_session                        = each.value.requires_session
  requires_duplicate_detection            = each.value.requires_duplicate_detection
  duplicate_detection_history_time_window = each.value.duplicate_detection_history_time_window
  default_message_ttl                     = each.value.default_message_ttl
  auto_delete_on_idle                     = each.value.auto_delete_on_idle
  dead_lettering_on_message_expiration    = each.value.dead_lettering_on_message_expiration
  batched_operations_enabled              = each.value.batched_operations_enabled
  express_enabled                         = each.value.express_enabled
  partitioning_enabled                    = each.value.partitioning_enabled
  forward_to                              = each.value.forward_to
  forward_dead_lettered_messages_to       = each.value.forward_dead_lettered_messages_to
  max_message_size_in_kilobytes           = each.value.max_message_size_in_kilobytes
  status                                  = each.value.status
}

resource "azurerm_servicebus_topic" "this" {
  for_each = var.topics

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this.id

  max_size_in_megabytes                   = each.value.max_size_in_megabytes
  requires_duplicate_detection            = each.value.requires_duplicate_detection
  duplicate_detection_history_time_window = each.value.duplicate_detection_history_time_window
  default_message_ttl                     = each.value.default_message_ttl
  auto_delete_on_idle                     = each.value.auto_delete_on_idle
  batched_operations_enabled              = each.value.batched_operations_enabled
  express_enabled                         = each.value.express_enabled
  partitioning_enabled                    = each.value.partitioning_enabled
  support_ordering                        = each.value.support_ordering
  max_message_size_in_kilobytes           = each.value.max_message_size_in_kilobytes
  status                                  = each.value.status
}

resource "azurerm_servicebus_subscription" "this" {
  for_each = local.subscriptions

  name     = each.value.sub_name
  topic_id = azurerm_servicebus_topic.this[each.value.topic_key].id

  max_delivery_count                        = each.value.max_delivery_count
  lock_duration                             = each.value.lock_duration
  requires_session                          = each.value.requires_session
  default_message_ttl                       = each.value.default_message_ttl
  auto_delete_on_idle                       = each.value.auto_delete_on_idle
  dead_lettering_on_message_expiration      = each.value.dead_lettering_on_message_expiration
  dead_lettering_on_filter_evaluation_error = each.value.dead_lettering_on_filter_evaluation_error
  batched_operations_enabled                = each.value.batched_operations_enabled
  forward_to                                = each.value.forward_to
  forward_dead_lettered_messages_to         = each.value.forward_dead_lettered_messages_to
  status                                    = each.value.status
}
