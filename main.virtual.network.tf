module "hub_virtual_networks" {
  for_each = var.hub_virtual_networks
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.7.1"

  name                    = each.value.name
  address_space           = each.value.address_space
  resource_group_name     = try(azurerm_resource_group.rg[each.key].name, each.value.resource_group_name)
  location                = each.value.location
  flow_timeout_in_minutes = each.value.flow_timeout_in_minutes

  ddos_protection_plan = each.value.ddos_protection_plan_id == null ? null : {
    id     = each.value.ddos_protection_plan_id
    enable = true
  }
  dns_servers = each.value.dns_servers == null ? null : {
    dns_servers = each.value.dns_servers
  }

  tags             = each.value.tags
  enable_telemetry = var.enable_telemetry
}

module "hub_virtual_network_subnets" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
  version  = "0.7.1"
  for_each = local.subnets

  virtual_network = {
    resource_id = each.value.virtual_network_id
  }
  name                                          = each.value.name
  address_prefixes                              = each.value.address_prefixes
  nat_gateway                                   = each.value.nat_gateway
  network_security_group                        = each.value.network_security_group
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
  service_endpoints                             = each.value.service_endpoints
  service_endpoint_policies                     = each.value.service_endpoint_policies
  delegation                                    = each.value.delegation
  route_table                                   = each.value.route_table
}

module "hub_virtual_network_peering" {
  for_each = local.peerings
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  version  = "0.7.1"

  virtual_network              = each.value.virtual_network
  remote_virtual_network       = each.value.remote_virtual_network
  name                         = each.value.name
  allow_forwarded_traffic      = each.value.allow_forwarded_traffic
  allow_gateway_transit        = each.value.allow_gateway_transit
  allow_virtual_network_access = each.value.allow_virtual_network_access
  use_remote_gateways          = each.value.use_remote_gateways
  create_reverse_peering       = false
}
