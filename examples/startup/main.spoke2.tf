resource "azurerm_resource_group" "spoke2" {
  location = "eastus2"
  name     = "spoke2-${random_pet.rand.id}"
}

module "spoke2_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.2.3"

  name                = "spoke2-vnet-${random_pet.rand.id}"
  address_space       = ["192.168.1.0/24"]
  resource_group_name = azurerm_resource_group.spoke2.name
  location            = azurerm_resource_group.spoke2.location

  peerings = {
    "spoke2-peering" = {
      name                                 = "spoke2-peering"
      remote_virtual_network_resource_id   = module.hub_mesh.virtual_networks["eastus2-hub"].id
      allow_forwarded_traffic              = true
      allow_gateway_transit                = false
      allow_virtual_network_access         = true
      use_remote_gateways                  = false
      create_reverse_peering               = true
      reverse_name                         = "spoke2-peering-back"
      reverse_allow_forwarded_traffic      = false
      reverse_allow_gateway_transit        = false
      reverse_allow_virtual_network_access = true
      reverse_use_remote_gateways          = false
    }
  }
  subnets = {
    spoke2-subnet = {
      name             = "spoke2-subnet"
      address_prefixes = ["192.168.1.0/24"]
      route_table = {
        id = azurerm_route_table.spoke2.id
      }
    }
  }
}

resource "azurerm_route_table" "spoke2" {
  location            = azurerm_resource_group.spoke2.location
  name                = "spoke2-rt"
  resource_group_name = azurerm_resource_group.spoke2.name
}

resource "azurerm_route" "spoke2_to_hub" {
  address_prefix         = "192.168.0.0/16"
  name                   = "to-hub"
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = azurerm_resource_group.spoke2.name
  route_table_name       = azurerm_route_table.spoke2.name
  next_hop_in_ip_address = module.hub_mesh.virtual_networks["eastus2-hub"].hub_router_ip_address
}

resource "azurerm_route" "spoke2_to_hub2" {
  address_prefix         = "10.0.0.0/8"
  name                   = "to-hub2"
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = azurerm_resource_group.spoke2.name
  route_table_name       = azurerm_route_table.spoke2.name
  next_hop_in_ip_address = module.hub_mesh.virtual_networks["eastus2-hub"].hub_router_ip_address
}

resource "azurerm_public_ip" "spoke2" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.spoke2.location
  name                = "vm1-pip"
  resource_group_name = azurerm_resource_group.spoke2.name
}

resource "azurerm_network_interface" "spoke2" {
  #checkov:skip=CKV_AZURE_119:It's only for connectivity test
  location            = azurerm_resource_group.spoke2.location
  name                = "spoke2-machine-nic"
  resource_group_name = azurerm_resource_group.spoke2.name

  ip_configuration {
    name                          = "nic"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke2.id
    subnet_id                     = module.spoke2_vnet.subnets["spoke2-subnet"].resource_id
  }
}

resource "azurerm_linux_virtual_machine" "spoke2" {
  #checkov:skip=CKV_AZURE_50:Only for connectivity test so we use vm extension
  #checkov:skip=CKV_AZURE_179:Only for connectivity test so we use vm extension
  admin_username = "adminuser"
  location       = azurerm_resource_group.spoke2.location
  name           = "spoke2-machine"
  network_interface_ids = [
    azurerm_network_interface.spoke2.id,
  ]
  resource_group_name = azurerm_resource_group.spoke2.name
  size                = "Standard_B2ms"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  admin_ssh_key {
    public_key = tls_private_key.key.public_key_openssh
    username   = "adminuser"
  }
  source_image_reference {
    offer     = "0001-com-ubuntu-server-jammy"
    publisher = "Canonical"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
