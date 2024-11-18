locals {
  virtual_network_id = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module.resource_id
  }
  virtual_network_name = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module.name
  }
}

locals {
  mesh_route_map = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for k_dst, v_dst in var.hub_virtual_networks : [
          for index, cidr in v_dst.routing_address_space : {
            hub                 = k_src
            key                 = "${k_src}-${k_dst}-${index}"
            name                = "${k_src}-${k_dst}-${replace(cidr, "/", "-")}"
            address_prefix      = cidr
            next_hop_type       = "VirtualAppliance"
            next_hop_ip_address = try(local.firewall_private_ip[k_dst], v_dst.hub_router_ip_address)
            resource_group_name = try(v_src.resource_group_name, azurerm_resource_group.rg[k_src].name)
          } if k_src != k_dst && v_dst.mesh_peering_enabled && can(v_dst.routing_address_space[0])
        ]
      ] if v_src.mesh_peering_enabled
    ]) : route.key => route
  }
  resource_groups = { for k, v in var.hub_virtual_networks : k => {
    name      = v.resource_group_name
    location  = v.location
    lock      = v.resource_group_lock_enabled
    lock_name = v.resource_group_lock_name
    tags      = v.resource_group_tags
    } if v.resource_group_creation_enabled
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
  user_route_map = {
    for route in flatten([
      for k_src, v_src in var.hub_virtual_networks : [
        for route_table_entry in v_src.route_table_entries : {
          hub                 = k_src
          name                = "${k_src}-${v_src.name}-${route_table_entry.name}"
          address_prefix      = route_table_entry.address_prefix
          next_hop_type       = route_table_entry.next_hop_type
          next_hop_ip_address = route_table_entry.next_hop_ip_address
          resource_group_name = try(v_src.resource_group_name, azurerm_resource_group.rg[k_src].name)
        }
      ]
    ]) : route.name => route
  }
}

