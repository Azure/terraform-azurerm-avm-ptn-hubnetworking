locals {
  firewall_internet_route_name    = "internet"
  firewall_management_subnet_name = "AzureFirewallManagementSubnet"
  firewall_management_subnets = {
    for k, v in var.hub_virtual_networks : "${k}-${local.firewall_management_subnet_name}" => {
      composite_key                                 = "${k}-${local.firewall_management_subnet_name}"
      virtual_network_key                           = k
      virtual_network_id                            = local.virtual_network_id[k]
      name                                          = local.firewall_management_subnet_name
      address_prefixes                              = [v.firewall.management_subnet_address_prefix]
      nat_gateway                                   = null
      network_security_group                        = null
      private_endpoint_network_policies             = null
      private_link_service_network_policies_enabled = null
      service_endpoints                             = null
      service_endpoint_policies                     = null
      delegation                                    = null
      route_table                                   = null
      default_outbound_access_enabled               = v.firewall.management_subnet_default_outbound_access_enabled
    }
    if v.firewall != null && try(v.firewall.management_ip_enabled, true)
  }
  firewall_route_table_ids = {
    # NOTE: For the destroy, you cannot delete the default route before removing the route table from the AzureFirewallSubnet.
    # Therefore we are building an implicit dependency on the default route here.
    for vnet_name, route in azurerm_route.firewall_default : vnet_name => replace(route.id, "/routes/${local.firewall_internet_route_name}", "")
  }
  firewall_subnet_name = "AzureFirewallSubnet"
  firewall_subnets = {
    for k, v in var.hub_virtual_networks : "${k}-${local.firewall_subnet_name}" => {
      composite_key                                 = "${k}-${local.firewall_subnet_name}"
      virtual_network_key                           = k
      virtual_network_id                            = local.virtual_network_id[k]
      name                                          = local.firewall_subnet_name
      address_prefixes                              = [v.firewall.subnet_address_prefix]
      nat_gateway                                   = null
      network_security_group                        = null
      private_endpoint_network_policies             = null
      private_link_service_network_policies_enabled = null
      service_endpoints                             = null
      service_endpoint_policies                     = null
      delegation                                    = null
      route_table                                   = { id = v.firewall.subnet_route_table_id != null ? v.firewall.subnet_route_table_id : local.firewall_route_table_ids[k] }
      default_outbound_access_enabled               = v.firewall.subnet_default_outbound_access_enabled
    } if v.firewall != null
  }
  subnets = merge(local.user_subnets, local.firewall_subnets, local.firewall_management_subnets)
  user_subnets = { for subnet in flatten([
    for k, v in var.hub_virtual_networks : [
      for subnetKey, subnet in v.subnets : [{
        composite_key                                 = "${k}-${subnetKey}"
        virtual_network_key                           = k
        virtual_network_id                            = local.virtual_network_id[k]
        name                                          = subnet.name
        address_prefixes                              = subnet.address_prefixes
        nat_gateway                                   = subnet.nat_gateway
        network_security_group                        = subnet.network_security_group
        private_endpoint_network_policies             = subnet.private_endpoint_network_policies_enabled ? "Enabled" : "Disabled"
        private_link_service_network_policies_enabled = subnet.private_link_service_network_policies_enabled
        service_endpoints                             = subnet.service_endpoints
        service_endpoint_policies                     = try(local.service_endpoint_policy_map[k][subnetKey], null)
        delegation                                    = subnet.delegations
        route_table                                   = try(subnet.route_table.assign_generated_route_table, true) ? (local.create_route_tables_user_subnets[k] ? { id = module.hub_routing_user_subnets[k].resource_id } : null) : (try(subnet.route_table.id, null) == null ? null : { id = subnet.route_table.id })
        default_outbound_access_enabled               = subnet.default_outbound_access_enabled
      }]
    ]]) : subnet.composite_key => subnet
  }
}
