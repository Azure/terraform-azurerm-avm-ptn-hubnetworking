# These locals defined here to avoid conflict with test framework
locals {
  firewall_private_ip = {
    for vnet_name, fw in module.hub_firewalls : vnet_name => fw.resource.ip_configuration[0].private_ip_address
  }
  hub_routing = azurerm_route_table.hub_routing
  virtual_networks_modules = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module
  }
}

# subnet.assign_generated_route_table ? { id = resource.azurerm_route_table.hub_routing[k].id } : subnet.external_route_table_id != null ? { id : subnet.external_route_table_id } : null

# Create rgs as defined by var.hub_networks
resource "azurerm_resource_group" "rg" {
  for_each = { for rg in local.resource_group_data : rg.name => rg }

  location = each.value.location
  name     = each.key
  tags     = each.value.tags
}

resource "azurerm_management_lock" "rg_lock" {
  for_each = { for r in local.resource_group_data : r.name => r if r.lock }

  lock_level = "CanNotDelete"
  name       = coalesce(each.value.lock_name, substr("lock-${each.key}", 0, 90))
  scope      = azurerm_resource_group.rg[each.key].id
}

# Module to create virtual networks and subnets
# Useful outputs:
# - vnet_id - the resource id of vnet
# - vnet_subnets_name_ids - a map of subnet name to subnet resource id, e.g. use lookup(module.hub_virtual_networks["key"].vnet_subnets_name_id, "subnet1")
module "hub_virtual_networks" {
  for_each = var.hub_virtual_networks
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.3.0"

  name                    = each.value.name
  address_space           = each.value.address_space
  resource_group_name     = try(azurerm_resource_group.rg[each.value.resource_group_name].name, each.value.resource_group_name)
  location                = each.value.location
  flow_timeout_in_minutes = each.value.flow_timeout_in_minutes

  ddos_protection_plan = each.value.ddos_protection_plan_id == null ? null : {
    id     = each.value.ddos_protection_plan_id
    enable = true
  }
  dns_servers = each.value.dns_servers == null ? null : {
    dns_servers = each.value.dns_servers
  }

  subnets          = try(local.subnets_map[each.key], {})
  tags             = each.value.tags
  enable_telemetry = var.enable_telemetry
}

module "hub_virtual_network_peering" {
  for_each = local.hub_peering_map
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  version  = "0.3.0"

  virtual_network = {
    resource_id = each.value.virtual_network_id
  }
  remote_virtual_network = {
    resource_id = each.value.remote_virtual_network_id
  }
  name                                 = each.value.name
  allow_forwarded_traffic              = each.value.allow_forwarded_traffic
  allow_gateway_transit                = each.value.allow_gateway_transit
  allow_virtual_network_access         = each.value.allow_virtual_network_access
  use_remote_gateways                  = each.value.use_remote_gateways
  create_reverse_peering               = each.value.create_reverse_peering
  reverse_name                         = each.value.reverse_name
  reverse_allow_forwarded_traffic      = each.value.reverse_allow_forwarded_traffic
  reverse_allow_gateway_transit        = each.value.reverse_allow_gateway_transit
  reverse_allow_virtual_network_access = each.value.reverse_allow_virtual_network_access
  reverse_use_remote_gateways          = each.value.reverse_use_remote_gateways
}

resource "azurerm_route_table" "hub_routing" {
  for_each = var.hub_virtual_networks

  location                      = each.value.location
  name                          = coalesce(var.hub_virtual_networks[each.key].route_table_name, "route-${each.key}")
  resource_group_name           = try(azurerm_resource_group.rg[each.value.resource_group_name].name, each.value.resource_group_name)
  disable_bgp_route_propagation = false
  tags                          = each.value.tags
}

resource "azurerm_route" "default_route" {
  for_each = var.hub_virtual_networks

  address_prefix      = "0.0.0.0/0"
  name                = "internet"
  next_hop_type       = "Internet"
  resource_group_name = azurerm_route_table.hub_routing[each.key].resource_group_name
  route_table_name    = azurerm_route_table.hub_routing[each.key].name
}

resource "azurerm_route" "mesh_routes" {
  for_each = local.mesh_route_map

  address_prefix         = each.value.address_prefix
  name                   = each.value.name
  next_hop_type          = each.value.next_hop_type
  resource_group_name    = azurerm_route_table.hub_routing[each.value.hub].resource_group_name
  route_table_name       = azurerm_route_table.hub_routing[each.value.hub].name
  next_hop_in_ip_address = each.value.next_hop_ip_address
}

resource "azurerm_route" "user_routes" {
  for_each = local.user_route_map

  address_prefix         = each.value.address_prefix
  name                   = each.value.name
  next_hop_type          = each.value.next_hop_type
  resource_group_name    = azurerm_route_table.hub_routing[each.value.hub].resource_group_name
  route_table_name       = azurerm_route_table.hub_routing[each.value.hub].name
  next_hop_in_ip_address = each.value.next_hop_ip_address
}

module "hub_firewalls" {
  for_each = local.firewalls
  source   = "Azure/avm-res-network-azurefirewall/azurerm"
  version  = "0.2.0"

  firewall_sku_name   = each.value.sku_name
  firewall_sku_tier   = each.value.sku_tier
  location            = var.hub_virtual_networks[each.key].location
  name                = each.value.name
  resource_group_name = var.hub_virtual_networks[each.key].resource_group_name
  firewall_ip_configuration = [{
    name                 = each.value.default_ip_configuration.name
    public_ip_address_id = module.fw_default_ips[each.key].public_ip_id
    subnet_id            = azurerm_subnet.fw_subnet[each.key].id
  }]
  firewall_management_ip_configuration = each.value.sku_tier != "Basic" ? null : {
    name                 = each.value.management_ip_configuration.name
    public_ip_address_id = module.fw_management_ips[each.key].public_ip_id
    subnet_id            = try(azurerm_subnet.fw_management_subnet[each.key].id, null)
  }
  firewall_policy_id         = each.value.firewall_policy_id
  firewall_private_ip_ranges = each.value.private_ip_ranges
  firewall_zones             = each.value.zones
  tags                       = each.value.tags
  enable_telemetry           = var.enable_telemetry
}

module "fw_default_ips" {
  for_each = local.fw_default_ip_configuration_pip
  source   = "Azure/avm-res-network-publicipaddress/azurerm"
  version  = "0.1.2"

  allocation_method   = "Static"
  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags                = each.value.tags
  zones               = each.value.zones

  enable_telemetry = var.enable_telemetry
}

module "fw_management_ips" {
  for_each = local.fw_management_ip_configuration_pip
  source   = "Azure/avm-res-network-publicipaddress/azurerm"
  version  = "0.1.2"

  allocation_method   = "Static"
  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags                = each.value.tags
  zones               = each.value.zones

  enable_telemetry = var.enable_telemetry
}

module "fw_policies" {
  for_each = local.fw_policies
  source   = "Azure/avm-res-network-firewallpolicy/azurerm"
  version  = "0.2.3"

  name                                              = each.value.name
  location                                          = var.hub_virtual_networks[each.key].location
  resource_group_name                               = var.hub_virtual_networks[each.key].resource_group_name
  firewall_policy_sku                               = each.value.sku
  firewall_policy_auto_learn_private_ranges_enabled = each.value.auto_learn_private_ranges_enabled
  firewall_policy_base_policy_id                    = each.value.base_policy_id
  firewall_policy_dns                               = each.value.dns
  firewall_policy_threat_intelligence_mode          = each.value.threat_intelligence_mode
  firewall_policy_private_ip_ranges                 = each.value.private_ip_ranges
  firewall_policy_threat_intelligence_allowlist     = each.value.threat_intelligence_allowlist
  tags                                              = each.value.tags

  enable_telemetry = var.enable_telemetry
}

resource "azurerm_subnet" "fw_subnet" {
  for_each = local.firewalls

  address_prefixes     = [each.value.subnet_address_prefix]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.hub_virtual_networks[each.key].resource_group_name
  virtual_network_name = module.hub_virtual_networks[each.key].name
}

resource "azurerm_subnet" "fw_management_subnet" {
  for_each = local.firewall_management_subnets

  address_prefixes     = each.value.address_prefixes
  name                 = each.value.name
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = each.value.virtual_network_name

  depends_on = [
    resource.azurerm_route.default_route
  ]
}

resource "azurerm_subnet_route_table_association" "fw_subnet_routing_create" {
  for_each = { for vnet_name, fw in local.firewalls : vnet_name => fw if fw.subnet_route_table_id == null }

  route_table_id = azurerm_route_table.hub_routing[each.key].id
  subnet_id      = azurerm_subnet.fw_subnet[each.key].id

  depends_on = [
    resource.azurerm_route.default_route
  ]
}

resource "azurerm_subnet_route_table_association" "fw_subnet_routing_external" {
  for_each = { for vnet_name, fw in local.firewalls : vnet_name => fw if fw.subnet_route_table_id != null }

  route_table_id = each.value.subnet_route_table_id
  subnet_id      = azurerm_subnet.fw_subnet[each.key].id
  depends_on = [
    module.hub_virtual_networks
  ]
}

