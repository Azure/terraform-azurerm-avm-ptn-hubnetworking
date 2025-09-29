locals {
  peerings = { for peering in flatten([for key_from, value_from in var.hub_virtual_networks : [
    for key_to, value_to in var.hub_virtual_networks : {
      name                         = try(value_from.peering_names[key_to], "${local.virtual_network_name[key_from]}-${local.virtual_network_name[key_to]}")
      composite_key                = "${key_from}-${key_to}"
      parent_id                    = local.virtual_network_id[key_from]
      remote_virtual_network_id    = local.virtual_network_id[key_to]
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = true
      use_remote_gateways          = false
    } if key_from != key_to && value_from.mesh_peering_enabled]
    ]) : peering.composite_key => peering
  }
}
