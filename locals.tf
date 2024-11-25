locals {
  virtual_network_id = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module.resource_id
  }
  virtual_network_name = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module.name
  }
}

locals {
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
}

