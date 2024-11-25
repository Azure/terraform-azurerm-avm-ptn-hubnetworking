module "hub_routing_firewall" {
  for_each = var.hub_virtual_networks
  source   = "Azure/avm-res-network-routetable/azurerm"
  version  = "0.3.1"

  location                      = each.value.location
  name                          = coalesce(var.hub_virtual_networks[each.key].route_table_name_firewall, "rt-firewall-${each.key}")
  resource_group_name           = try(each.value.resource_group_name, azurerm_resource_group.rg[each.key].name)
  bgp_route_propagation_enabled = true
  tags                          = each.value.tags
  enable_telemetry              = var.enable_telemetry
}

resource "azurerm_route" "firewall_default" {
  for_each = local.default_route_internet

  address_prefix         = each.value.address_prefix
  name                   = each.value.name
  next_hop_type          = each.value.next_hop_type
  resource_group_name    = each.value.resource_group_name
  route_table_name       = module.hub_routing_firewall[each.value.virtual_network_key].name
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

resource "azurerm_route" "firewall_mesh" {
  for_each = local.final_route_map_firewall

  address_prefix         = each.value.address_prefix
  name                   = each.value.name
  next_hop_type          = each.value.next_hop_type
  resource_group_name    = each.value.resource_group_name
  route_table_name       = module.hub_routing_firewall[each.value.virtual_network_key].name
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

module "hub_routing_user_subnets" {
  for_each = var.hub_virtual_networks
  source   = "Azure/avm-res-network-routetable/azurerm"
  version  = "0.3.1"

  location                      = each.value.location
  name                          = coalesce(var.hub_virtual_networks[each.key].route_table_name_user_subnets, "rt-user-subnets-${each.key}")
  resource_group_name           = try(each.value.resource_group_name, azurerm_resource_group.rg[each.key].name)
  bgp_route_propagation_enabled = true
  tags                          = each.value.tags
  enable_telemetry              = var.enable_telemetry
}

resource "azurerm_route" "user_subnets" {
  for_each = local.final_route_map_user_subnets

  address_prefix         = each.value.address_prefix
  name                   = each.value.name
  next_hop_type          = each.value.next_hop_type
  resource_group_name    = each.value.resource_group_name
  route_table_name       = module.hub_routing_user_subnets[each.value.virtual_network_key].name
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}
