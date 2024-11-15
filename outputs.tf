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

output "hub_route_tables" {
  description = "A curated output of the route tables created by this module."
  value = {
    for vnet_name, rt in module.hub_routing : vnet_name => {
      name = rt.name
      id   = rt.resource_id
      routes = [
        for r in rt.routes : {
          name                   = r.name
          address_prefix         = r.address_prefix
          next_hop_type          = r.next_hop_type
          next_hop_in_ip_address = r.next_hop_in_ip_address
        }
      ]
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
    for vnet_name, vnet_mod in module.hub_virtual_networks : vnet_name => {
      name                        = vnet_mod.name
      resource_group_name         = var.hub_virtual_networks[vnet_name].resource_group_name
      id                          = vnet_mod.resource_id
      virtual_network_resource_id = vnet_mod.resource.id
      location                    = var.hub_virtual_networks[vnet_name].location
      address_spaces              = var.hub_virtual_networks[vnet_name].address_space
      subnets_name_id             = vnet_mod.subnets
      subnets                     = vnet_mod.subnets
      subnet_ids                  = { for subnet_key, subnet_value in vnet_mod.subnets : subnet_key => subnet_value.resource_id }
      hub_router_ip_address       = try(module.hub_firewalls[vnet_name].resource.ip_configuration[0].private_ip_address, var.hub_virtual_networks[vnet_name].hub_router_ip_address)
    }
  }
}
