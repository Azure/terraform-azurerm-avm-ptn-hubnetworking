output "spoke2_pip" {
  depends_on = [azurerm_linux_virtual_machine.spoke2]
  value      = azurerm_public_ip.spoke2.ip_address
}

output "testing" {
  value = module.hub_mesh.testing
}

output "testing2" {
  value = module.hub_mesh.testing2
}

output "testing3" {
  value = module.hub_mesh.testing3
}
