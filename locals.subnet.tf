locals {
  firewall_management_subnet_name = "AzureFirewallManagementSubnet"
  firewall_management_subnets = {
    for k, v in var.hub_virtual_networks : "${k}-${local.firewall_management_subnet_name}" => {
      composite_key                                 = "${k}-${local.firewall_management_subnet_name}"
      virtual_newtork_key                           = k
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
    }
    if try(v.firewall.sku_tier, "FirewallNull") == "Basic" && v.firewall != null
  }
  firewall_subnet_name = "AzureFirewallSubnet"
  firewall_subnets = {
    for k, v in local.firewalls : "${k}-${local.firewall_subnet_name}" => {
      composite_key                                 = "${k}-${local.firewall_subnet_name}"
      virtual_newtork_key                           = k
      virtual_network_id                            = local.virtual_network_id[k]
      name                                          = local.firewall_subnet_name
      address_prefixes                              = [v.subnet_address_prefix]
      nat_gateway                                   = null
      network_security_group                        = null
      private_endpoint_network_policies             = null
      private_link_service_network_policies_enabled = null
      service_endpoints                             = null
      service_endpoint_policies                     = null
      delegation                                    = null
      route_table                                   = { id = v.subnet_route_table_id }
    }
  }
  subnets = merge(local.user_subnets, local.firewall_subnets, local.firewall_management_subnets)
  user_subnets = { for subnet in flatten([
    for k, v in var.hub_virtual_networks : [
      for subnetKey, subnet in v.subnets : [{
        composite_key                                 = "${k}-${subnetKey}"
        virtual_newtork_key                           = k
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
        route_table                                   = subnet.assign_generated_route_table ? { id = module.hub_routing[k].resource_id } : subnet.external_route_table_id != null ? { id : subnet.external_route_table_id } : null
      }]
    ]]) : subnet.composite_key => subnet
  }
}
