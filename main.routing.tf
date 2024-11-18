module "hub_routing" {
  for_each = var.hub_virtual_networks
  source   = "Azure/avm-res-network-routetable/azurerm"
  version  = "0.3.1"

  location                      = each.value.location
  name                          = coalesce(var.hub_virtual_networks[each.key].route_table_name, "route-${each.key}")
  resource_group_name           = try(each.value.resource_group_name, azurerm_resource_group.rg[each.key].name)
  bgp_route_propagation_enabled = true
  tags                          = each.value.tags

  enable_telemetry = var.enable_telemetry
}

resource "azurerm_route" "default_route" {
  for_each = var.hub_virtual_networks

  address_prefix      = "0.0.0.0/0"
  name                = "internet"
  next_hop_type       = "Internet"
  resource_group_name = try(each.value.resource_group_name, azurerm_resource_group.rg[each.key].name)
  route_table_name    = module.hub_routing[each.key].name
}

resource "azurerm_route" "mesh_routes" {
  for_each = local.mesh_route_map

  address_prefix         = each.value.address_prefix
  name                   = each.value.name
  next_hop_type          = each.value.next_hop_type
  resource_group_name    = each.value.resource_group_name
  route_table_name       = module.hub_routing[each.value.hub].name
  next_hop_in_ip_address = each.value.next_hop_ip_address
}

resource "azurerm_route" "user_routes" {
  for_each = local.user_route_map

  address_prefix         = each.value.address_prefix
  name                   = each.value.name
  next_hop_type          = each.value.next_hop_type
  resource_group_name    = each.value.resource_group_name
  route_table_name       = module.hub_routing[each.value.hub].name
  next_hop_in_ip_address = each.value.next_hop_ip_address
}
