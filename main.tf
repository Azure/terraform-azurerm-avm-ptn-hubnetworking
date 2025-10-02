module "hub_virtual_networks" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.12.0"
  for_each = var.hub_virtual_networks

  address_space = each.value.address_space
  location      = each.value.location
  parent_id     = each.value.parent_id
  ddos_protection_plan = each.value.ddos_protection_plan_id == null ? null : {
    id     = each.value.ddos_protection_plan_id
    enable = true
  }
  dns_servers = each.value.dns_servers == null ? null : {
    dns_servers = each.value.dns_servers
  }
  enable_telemetry        = var.enable_telemetry
  flow_timeout_in_minutes = each.value.flow_timeout_in_minutes
  name                    = each.value.name
  tags                    = each.value.tags == null ? var.tags : each.value.tags
}

module "hub_virtual_network_subnets" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
  version  = "0.12.0"
  for_each = local.subnets

  parent_id                                     = each.value.virtual_network_id
  address_prefixes                              = each.value.address_prefixes
  default_outbound_access_enabled               = each.value.default_outbound_access_enabled
  delegation                                    = each.value.delegation
  name                                          = each.value.name
  nat_gateway                                   = each.value.nat_gateway
  network_security_group                        = each.value.network_security_group
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
  route_table                                   = each.value.route_table
  service_endpoint_policies                     = each.value.service_endpoint_policies
  service_endpoints                             = each.value.service_endpoints
}

module "hub_virtual_network_peering" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  version  = "0.12.0"
  for_each = local.peerings

  parent_id                    = each.value.parent_id
  allow_forwarded_traffic      = each.value.allow_forwarded_traffic
  allow_gateway_transit        = each.value.allow_gateway_transit
  allow_virtual_network_access = each.value.allow_virtual_network_access
  create_reverse_peering       = false
  name                         = each.value.name
  remote_virtual_network_id    = each.value.remote_virtual_network_id
  use_remote_gateways          = each.value.use_remote_gateways
}
