locals {
  resource_group_names = {
    for k, v in var.hub_virtual_networks : k => provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", v.parent_id).resource_group_name
  }
}

locals {
  virtual_network_id = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module.resource_id
  }
  virtual_network_name = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module.name
  }
}

locals {
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

