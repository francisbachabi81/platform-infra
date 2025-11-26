locals {
  # enforce a valid acr name (a-z0-9 only, 5-50 chars)
  name_sanitized = substr(replace(lower(var.registry_name), "[^a-z0-9]", ""), 0, 50)
  name_effective = length(local.name_sanitized) < 5 ? "acr${local.name_sanitized}xx" : local.name_sanitized

  is_premium = lower(var.sku) == "premium"
}

resource "azurerm_container_registry" "this" {
  name                = local.name_effective
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = var.public_network_access
  anonymous_pull_enabled        = var.anonymous_pull_enabled

  # only apply ZRS if premium
  zone_redundancy_enabled = local.is_premium ? var.zone_redundancy_enabled : false

  # only set retention policy on premium
  retention_policy_in_days = (local.is_premium && var.retention_untagged_enabled) ? var.retention_untagged_days : null

  tags = var.tags
}

# optional role assignments (spns, groups, users)
resource "azurerm_role_assignment" "acr_roles" {
  for_each             = { for i, r in var.role_assignments : i => r }
  scope                = azurerm_container_registry.this.id
  principal_id         = each.value.principal_id
  role_definition_name = each.value.role_definition_name
}
