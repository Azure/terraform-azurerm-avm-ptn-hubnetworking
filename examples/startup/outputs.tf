output "spoke2_pip" {
  depends_on = [module.vm_spoke2]
  value      = module.vm_spoke2.public_ips["network_interface_1-ip_configurations_1"].ip_address
}
