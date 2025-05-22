resource "azurerm_resource_group" "rg" {
  for_each = local.resource_groups

  location = each.value.location
  name     = each.value.name
  tags     = each.value.tags == null ? var.tags : each.value.tags
}

resource "azurerm_management_lock" "rg_lock" {
  for_each = { for k, v in local.resource_groups : k => v if v.lock }

  lock_level = "CanNotDelete"
  name       = coalesce(each.value.lock_name, substr("lock-${each.value.name}", 0, 90))
  scope      = azurerm_resource_group.rg[each.key].id
}
