output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "virtual_network_id" {
  value = module.hub.virtual_networks["hub"].id
}

output "firewall_id" {
  value = module.hub.firewalls["hub"].id
}

output "firewall_ip_address" {
  value = module.hub.firewalls["hub"].public_ip_address
}
