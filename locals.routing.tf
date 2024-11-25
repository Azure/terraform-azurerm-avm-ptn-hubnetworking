locals {
  default_route_internet = {
    for key, value in var.hub_virtual_networks : key => {
      virtual_network_key    = key
      key                    = key
      name                   = local.firewall_internet_route_name
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "Internet"
      next_hop_in_ip_address = null
      resource_group_name    = try(value.resource_group_name, azurerm_resource_group.rg[key].name)
    }
  }
  final_route_map_firewall     = merge(local.mesh_route_map_firewall, local.route_table_entries_firewall)
  final_route_map_user_subnets = merge(local.mesh_route_map_internet, local.mesh_route_map_user_subnets, local.route_table_entries_user_subnet)
  firewall_private_ip = {
    for vnet_name, fw in module.hub_firewalls : vnet_name => fw.resource.ip_configuration[0].private_ip_address
  }
  mesh_route_map_firewall = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for k_dst, v_dst in var.hub_virtual_networks : [
          for index, cidr in v_dst.routing_address_space : {
            virtual_network_key    = k_src
            key                    = "${k_src}-${k_dst}-${index}"
            name                   = "${k_src}-${k_dst}-${replace(cidr, "/", "-")}"
            address_prefix         = cidr
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = try(local.firewall_private_ip[k_dst], v_dst.hub_router_ip_address)
            resource_group_name    = try(v_src.resource_group_name, azurerm_resource_group.rg[k_src].name)
          } if k_src != k_dst && v_dst.mesh_peering_enabled && can(v_dst.routing_address_space[0])
        ]
      ] if v_src.mesh_peering_enabled
    ]) : route.key => route
  }
  mesh_route_map_internet = {
    for key, value in var.hub_virtual_networks : "${key}-internet" => {
      virtual_network_key    = key
      key                    = "${key}-internet"
      name                   = "${key}-0.0.0.0-0"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = try(local.firewall_private_ip[key], value.hub_router_ip_address)
      resource_group_name    = try(value.resource_group_name, azurerm_resource_group.rg[key].name)
    }
  }
  mesh_route_map_user_subnets = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for k_dst, v_dst in var.hub_virtual_networks : [
          for index, cidr in v_dst.routing_address_space : {
            virtual_network_key    = k_src
            key                    = "${k_src}-${k_dst}-${index}"
            name                   = "${k_src}-${k_dst}-${replace(cidr, "/", "-")}"
            address_prefix         = cidr
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = try(local.firewall_private_ip[k_dst], v_dst.hub_router_ip_address)
            resource_group_name    = try(v_src.resource_group_name, azurerm_resource_group.rg[k_src].name)
          } if v_dst.mesh_peering_enabled && can(v_dst.routing_address_space[0])
        ]
      ] if v_src.mesh_peering_enabled
    ]) : route.key => route
  }
  route_table_entries_firewall = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for route_table_entry in v_src.route_table_entries_firewall : {
          virtual_network_key    = k_src
          name                   = "${k_src}-${v_src.name}-${route_table_entry.name}"
          address_prefix         = route_table_entry.address_prefix
          next_hop_type          = route_table_entry.next_hop_type
          next_hop_in_ip_address = route_table_entry.next_hop_ip_address
          resource_group_name    = try(v_src.resource_group_name, azurerm_resource_group.rg[k_src].name)
        }
      ]
    ]) : route.name => route
  }
  route_table_entries_user_subnet = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for route_table_entry in v_src.route_table_entries_user_subnets : {
          virtual_network_key    = k_src
          name                   = "${k_src}-${v_src.name}-${route_table_entry.name}"
          address_prefix         = route_table_entry.address_prefix
          next_hop_type          = route_table_entry.next_hop_type
          next_hop_in_ip_address = route_table_entry.next_hop_ip_address
          resource_group_name    = try(v_src.resource_group_name, azurerm_resource_group.rg[k_src].name)
        }
      ]
    ]) : route.name => route
  }
}
