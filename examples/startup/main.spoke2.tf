resource "azurerm_resource_group" "spoke2" {
  location = local.regions.secondary
  name     = "spoke2-${random_pet.rand.id}"
}

module "spoke2_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.7.1"

  name                = "spoke2-vnet-${random_pet.rand.id}"
  address_space       = ["192.168.1.0/24"]
  resource_group_name = azurerm_resource_group.spoke2.name
  location            = azurerm_resource_group.spoke2.location

  peerings = {
    "spoke2-peering" = {
      name                                 = "spoke2-peering"
      remote_virtual_network_resource_id   = module.hub_mesh.virtual_networks["secondary-hub"].id
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
        id = module.route_table_spoke_2.resource_id
      }
    }
  }
}

module "route_table_spoke_2" {
  source  = "Azure/avm-res-network-routetable/azurerm"
  version = "0.3.1"

  location            = azurerm_resource_group.spoke2.location
  name                = "spoke2-rt"
  resource_group_name = azurerm_resource_group.spoke2.name

  routes = {
    spoke2_to_hub = {
      address_prefix         = "192.168.0.0/16"
      name                   = "to-hub"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.hub_mesh.virtual_networks["secondary-hub"].hub_router_ip_address
    }
    spoke2_to_hub2 = {
      address_prefix         = "10.0.0.0/8"
      name                   = "to-hub2"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.hub_mesh.virtual_networks["secondary-hub"].hub_router_ip_address
    }
  }
}

module "vm_spoke2" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.15.1"

  location                           = azurerm_resource_group.spoke2.location
  name                               = "spoke2-machine"
  resource_group_name                = azurerm_resource_group.spoke2.name
  zone                               = 1
  admin_username                     = "adminuser"
  generate_admin_password_or_ssh_key = false

  admin_ssh_keys = [{
    public_key = tls_private_key.key.public_key_openssh
    username   = "adminuser"
  }]

  os_type  = "linux"
  sku_size = "Standard_B1s"

  network_interfaces = {
    network_interface_1 = {
      name = "nic"
      ip_configurations = {
        ip_configurations_1 = {
          name                          = "nic"
          private_ip_address_allocation = "Dynamic"
          private_ip_subnet_resource_id = module.spoke2_vnet.subnets["spoke2-subnet"].resource_id
          create_public_ip_address      = true
          public_ip_address_name        = "vm1-pip"
        }
      }
    }
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference = {
    offer     = "0001-com-ubuntu-server-jammy"
    publisher = "Canonical"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
