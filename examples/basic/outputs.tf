output "firewall_id" {
  value = module.hub.firewalls["hub"].id
}

output "firewall_ip_addresses" {
  value = module.hub.firewalls["hub"].public_ip_addresses
}

output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "subnet_ids" {
  value = module.hub.virtual_networks["hub"].subnet_ids
}

output "virtual_network_id" {
  value = module.hub.virtual_networks["hub"].id
}
