output "firewalls" {
  description = "A curated output of the firewalls created by this module."
  value = {
    for vnet_name, fw in module.hub_firewalls : vnet_name => {
      id                           = fw.resource_id
      name                         = fw.resource.name
      private_ip_address           = try(fw.resource.ip_configuration[0].private_ip_address, null)
      public_ip_address            = try(module.fw_default_ips[vnet_name].public_ip_address)
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
      name = rt.name
      id   = rt.resource_id
    }
  }
}

output "resource_groups" {
  description = "A curated output of the resource groups created by this module."
  value = {
    for rg_name, rg in azurerm_resource_group.rg : rg_name => {
      name     = rg.name
      location = rg.location
      id       = rg.id
    }
  }
}

output "virtual_networks" {
  description = "A curated output of the virtual networks created by this module."
  value = {
    for vnet_key, vnet_mod in module.hub_virtual_networks : vnet_key => {
      name                        = vnet_mod.name
      resource_group_name         = var.hub_virtual_networks[vnet_key].resource_group_name
      id                          = vnet_mod.resource_id
      virtual_network_resource_id = vnet_mod.resource.id
      location                    = var.hub_virtual_networks[vnet_key].location
      address_spaces              = var.hub_virtual_networks[vnet_key].address_space
      subnets                     = { for subnet_key, subnet_value in local.subnets : subnet_key => module.hub_virtual_network_subnets[subnet_key] if subnet_value.virtual_newtork_key == vnet_key }
      subnet_ids                  = { for subnet_key, subnet_value in local.subnets : subnet_key => module.hub_virtual_network_subnets[subnet_key].resource_id if subnet_value.virtual_newtork_key == vnet_key }
      hub_router_ip_address       = try(module.hub_firewalls[vnet_key].resource.ip_configuration[0].private_ip_address, var.hub_virtual_networks[vnet_key].hub_router_ip_address)
    }
  }
}
