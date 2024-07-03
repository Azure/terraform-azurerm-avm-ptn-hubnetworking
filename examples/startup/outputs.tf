output "spoke2_pip" {
  depends_on = [azurerm_linux_virtual_machine.spoke2]
  value      = azurerm_public_ip.spoke2.ip_address
}


output "testing1" {
  value = module.hub_mesh.testing1
}
