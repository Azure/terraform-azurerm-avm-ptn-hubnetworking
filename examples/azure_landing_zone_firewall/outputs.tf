output "firewall_policies" {
  value = module.hub_mesh.firewall_policies
}

output "firewalls" {
  value = module.hub_mesh.firewalls
}

output "resource_groups" {
  value = module.hub_mesh.resource_groups
}

output "route_tables_firewall" {
  value = module.hub_mesh.hub_route_tables_firewall
}

output "route_tables_user_subnets" {
  value = module.hub_mesh.hub_route_tables_user_subnets
}

output "virtual_networks" {
  value = module.hub_mesh.virtual_networks
}
