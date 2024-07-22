locals {
  firewall_management_subnets = {
    for k, v in var.hub_virtual_networks : k => {
      address_prefixes     = [v.firewall.management_subnet_address_prefix]
      name                 = "AzureFirewallManagementSubnet"
      resource_group_name  = v.resource_group_name
      virtual_network_name = v.name
    }
    if try(v.firewall.sku_tier, "FirewallNull") == "Basic" && v.firewall != null
  }
  firewalls = {
    for vnet_name, vnet in var.hub_virtual_networks : vnet_name => {
      name                  = coalesce(vnet.firewall.name, "afw-${vnet_name}")
      sku_name              = vnet.firewall.sku_name
      sku_tier              = vnet.firewall.sku_tier
      subnet_address_prefix = vnet.firewall.subnet_address_prefix
      subnet_route_table_id = vnet.firewall.subnet_route_table_id
      dns_servers           = vnet.firewall.dns_servers
      firewall_policy_id    = vnet.firewall.firewall_policy_id
      private_ip_ranges     = vnet.firewall.private_ip_ranges
      tags                  = vnet.firewall.tags
      threat_intel_mode     = vnet.firewall.threat_intel_mode
      default_ip_configuration = {
        name = try(coalesce(vnet.firewall.management_ip_configuration.name, "default"), "default")
      }
      management_ip_configuration = {
        name = try(coalesce(vnet.firewall.management_ip_configuration.name, "defaultMgmt"), "defaultMgmt")
      }
      zones = vnet.firewall.zones
    } if vnet.firewall != null
  }
  fw_default_ip_configuration_pip = {
    for vnet_name, vnet in var.hub_virtual_networks : vnet_name => {
      location            = vnet.location
      name                = try(vnet.firewall.default_ip_configuration.public_ip_config.name, "pip-afw-${vnet_name}")
      resource_group_name = vnet.resource_group_name
      ip_version          = try(vnet.firewall.default_ip_configuration.public_ip_config.ip_version, "IPv4")
      sku_tier            = try(vnet.firewall.default_ip_configuration.public_ip_config.sku_tier, "Regional")
      tags                = vnet.firewall.tags
      zones               = try(vnet.firewall.default_ip_configuration.public_ip_config.zones, null)
    } if vnet.firewall != null
  }
  fw_management_ip_configuration_pip = {
    for vnet_name, vnet in var.hub_virtual_networks : vnet_name => {
      location            = vnet.location
      name                = try(vnet.firewall.management_ip_configuration.public_ip_config.name, "pip-afw-mgmt-${vnet_name}")
      resource_group_name = vnet.resource_group_name
      ip_version          = try(vnet.firewall.management_ip_coniguration.public_ip_config.ip_version, "IPv4")
      sku_tier            = try(vnet.firewall.management_ip_coniguration.public_ip_config.sku_tier, "Regional")
      tags                = vnet.firewall.tags
      zones               = try(vnet.firewall.management_ip_coniguration.public_ip_config.zones, null)
    } if try(vnet.firewall.sku_tier, "FirewallNull") == "Basic" && vnet.firewall != null
  }
  indexed_hub_virtual_networks = [
    for k, v in var.hub_virtual_networks : {
      key   = k
      value = v
    }
  ]
  hub_peering_map = {
    for peerconfig in flatten([
      for src_index, src_data in local.indexed_hub_virtual_networks :
      [
        for dst_index, dst_data in local.indexed_hub_virtual_networks :
        {
          name                                 = "${local.virtual_networks_modules[src_data.key].name}-${local.virtual_networks_modules[dst_data.key].name}"
          src_key                              = src_data.key
          dst_key                              = dst_data.key
          virtual_network_id                   = local.virtual_networks_modules[src_data.key].resource_id
          remote_virtual_network_id            = local.virtual_networks_modules[dst_data.key].resource_id
          allow_virtual_network_access         = true
          allow_forwarded_traffic              = true
          allow_gateway_transit                = true
          use_remote_gateways                  = false
          create_reverse_peering               = true
          reverse_name                         = "${local.virtual_networks_modules[dst_data.key].name}-${local.virtual_networks_modules[src_data.key].name}"
          reverse_allow_virtual_network_access = true
          reverse_allow_forwarded_traffic      = true
          reverse_allow_gateway_transit        = true
          reverse_use_remote_gateways          = false
        } if src_index > dst_index && dst_data.value.mesh_peering_enabled
      ] if src_data.value.mesh_peering_enabled
    ]) : peerconfig.name => peerconfig
  }
  resource_group_data = toset([
    for k, v in var.hub_virtual_networks : {
      name      = v.resource_group_name
      location  = v.location
      lock      = v.resource_group_lock_enabled
      lock_name = v.resource_group_lock_name
      tags      = v.resource_group_tags
    } if v.resource_group_creation_enabled
  ])
  mesh_route_map = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for k_dst, v_dst in var.hub_virtual_networks : [
          for cidr in v_dst.routing_address_space : {
            hub                 = k_src
            name                = "${k_src}-${k_dst}-${replace(cidr, "/", "-")}"
            address_prefix      = cidr
            next_hop_type       = "VirtualAppliance"
            next_hop_ip_address = try(local.firewall_private_ip[k_dst], v_dst.hub_router_ip_address)
          }
          if k_src != k_dst && v_dst.mesh_peering_enabled && can(v_dst.routing_address_space[0])
        ]
      ]
    ]) : route.name => route
  }
  user_route_map = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for route_table_entry in v_src.route_table_entries : {
          hub                 = k_src
          name                = "${k_src}-${v_src.name}-${route_table_entry.name}"
          address_prefix      = route_table_entry.address_prefix
          next_hop_type       = route_table_entry.next_hop_type
          next_hop_ip_address = route_table_entry.next_hop_ip_address
        }
      ]
    ]) : route.name => route
  }
  subnet_external_route_table_association_map = {
    for assoc in flatten([
      for k, v in var.hub_virtual_networks : [
        for subnetName, subnet in v.subnets : {
          name           = "${k}-${subnetName}"
          subnet_id      = lookup(local.virtual_networks_modules[k].subnets, subnetName)
          route_table_id = subnet.external_route_table_id
        } if subnet.external_route_table_id != null
      ]
    ]) : assoc.name => assoc
  }
  subnet_route_table_association_map = {
    for assoc in flatten([
      for k, v in var.hub_virtual_networks : [
        for subnetName, subnet in v.subnets : {
          name           = "${k}-${subnetName}"
          subnet_id      = lookup(local.virtual_networks_modules[k].subnets, subnetName).resource_id
          route_table_id = local.hub_routing[k].id
        } if subnet.assign_generated_route_table
      ]
    ]) : assoc.name => assoc
  }
  service_endpoint_policy_map = {
    for k, v in var.hub_virtual_networks : k => {
      for subnetKey, subnet in v.subnets : subnetKey => {
        for index, policy_id in tolist(subnet.service_endpoint_policy_ids) : index => {
          id = policy_id
        }
      } if subnet.service_endpoint_policy_ids != null
    }
  }
  subnets_map = {
    for k, v in var.hub_virtual_networks : k => {
      for subnetKey, subnet in v.subnets : subnetKey => {
        name                                          = subnet.name
        address_prefixes                              = subnet.address_prefixes
        nat_gateway                                   = subnet.nat_gateway
        network_security_group                        = subnet.network_security_group
        private_endpoint_network_policies             = subnet.private_endpoint_network_policies_enabled ? "Enabled" : "Disabled"
        private_link_service_network_policies_enabled = subnet.private_link_service_network_policies_enabled
        service_endpoints                             = subnet.service_endpoints
        service_endpoint_policies                     = try(local.service_endpoint_policy_map[k][subnetKey], null)
        delegation                                    = subnet.delegations
        #        route_table                                   = subnet.assign_generated_route_table ? { id = resource.azurerm_route_table.hub_routing[k].id } : subnet.external_route_table_id != null ? { id : subnet.external_route_table_id } : null
      }
    }
  }
}

