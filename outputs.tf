output "firewall_policies" {
  description = "A curated output of the firewall policies created by this module."
  value = {
    for vnet_name, fw_policy in module.fw_policies : vnet_name => {
      id   = fw_policy.resource_id
      name = fw_policy.resource.name
    }
  }
}

output "firewalls" {
  description = "A curated output of the firewalls created by this module."
  value = {
    for vnet_name, fw in module.hub_firewalls : vnet_name => {
      id                           = fw.resource_id
      name                         = fw.resource.name
      private_ip_address           = try(fw.resource.ip_configuration[0].private_ip_address, null)
      public_ip_addresses          = try([for k, pip in module.fw_default_ips : pip.public_ip_address if startswith(k, "${vnet_name}-") || k == vnet_name], [])
      management_public_ip_address = try(module.fw_management_ips[vnet_name].public_ip_address, null)
    }
  }
}

output "hub_route_tables_firewall" {
  description = "A curated output of the route tables created by this module."
  value = {
    for vnet_name, rt in module.hub_routing_firewall : vnet_name => {
      name = rt.name
      id   = rt.resource_id
    }
  }
}

output "hub_route_tables_user_subnets" {
  description = "A curated output of the route tables created by this module."
  value = {
    for vnet_name, rt in module.hub_routing_user_subnets : vnet_name => {
      name = rt.resource.name
      id   = rt.resource_id
    }
  }
}

output "name" {
  description = "The names of the hub virtual networks."
  value       = { for key, value in module.hub_virtual_networks : key => value.name }
}

output "resource_id" {
  description = "The resource IDs of the hub virtual networks."
  value       = { for key, value in module.hub_virtual_networks : key => value.resource_id }
}

output "virtual_networks" {
  description = "A curated output of the virtual networks created by this module."
  value = {
    for vnet_key, vnet_mod in module.hub_virtual_networks : vnet_key => {
      name                        = vnet_mod.name
      parent_id                   = var.hub_virtual_networks[vnet_key].parent_id
      resource_group_name         = local.resource_group_names[vnet_key]
      id                          = vnet_mod.resource_id
      virtual_network_resource_id = vnet_mod.resource.id
      location                    = var.hub_virtual_networks[vnet_key].location
      address_spaces              = var.hub_virtual_networks[vnet_key].address_space
      subnets                     = { for subnet_key, subnet_value in local.subnets : subnet_key => module.hub_virtual_network_subnets[subnet_key] if subnet_value.virtual_network_key == vnet_key }
      subnet_ids                  = { for subnet_key, subnet_value in local.subnets : subnet_key => module.hub_virtual_network_subnets[subnet_key].resource_id if subnet_value.virtual_network_key == vnet_key }
      hub_router_ip_address       = try(module.hub_firewalls[vnet_key].resource.ip_configuration[0].private_ip_address, var.hub_virtual_networks[vnet_key].hub_router_ip_address)
    }
  }
}
