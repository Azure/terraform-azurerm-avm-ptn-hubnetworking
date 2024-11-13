resource "azurerm_resource_group" "spoke1" {
  location = local.regions.primary
  name     = "spoke1-${random_pet.rand.id}"
}

module "spoke1_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.6.0"

  name                = "spoke1-vnet-${random_pet.rand.id}"
  address_space       = ["192.168.0.0/24"]
  resource_group_name = azurerm_resource_group.spoke1.name
  location            = azurerm_resource_group.spoke1.location

  peerings = {
    "spoke1-peering" = {
      name                                 = "spoke1-peering"
      remote_virtual_network_resource_id   = module.hub_mesh.virtual_networks["primary-hub"].id
      allow_forwarded_traffic              = true
      allow_gateway_transit                = false
      allow_virtual_network_access         = true
      use_remote_gateways                  = false
      create_reverse_peering               = true
      reverse_name                         = "spoke1-peering-back"
      reverse_allow_forwarded_traffic      = false
      reverse_allow_gateway_transit        = false
      reverse_allow_virtual_network_access = true
      reverse_use_remote_gateways          = false
    }
  }
  subnets = {
    spoke1-subnet = {
      name             = "spoke1-subnet"
      address_prefixes = ["192.168.0.0/24"]
      route_table = {
        id = module.route_table_spoke1.resource_id
      }
    }
  }
}

module "route_table_spoke1" {
  source  = "Azure/avm-res-network-routetable/azurerm"
  version = "0.2.2"

  location            = azurerm_resource_group.spoke1.location
  name                = "spoke1-rt"
  resource_group_name = azurerm_resource_group.spoke1.name

  routes = {
    spoke1_to_hub = {
      address_prefix         = "192.168.0.0/16"
      name                   = "to-hub"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.hub_mesh.virtual_networks["primary-hub"].hub_router_ip_address
    }
    spoke1_to_hub2 = {
      address_prefix         = "10.0.0.0/8"
      name                   = "to-hub2"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.hub_mesh.virtual_networks["primary-hub"].hub_router_ip_address
    }
  }
}

module "vm_spoke1" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.15.1"

  location                           = azurerm_resource_group.spoke1.location
  name                               = "spoke1-machine"
  resource_group_name                = azurerm_resource_group.spoke1.name
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
      name = "internal"
      ip_configurations = {
        ip_configurations_1 = {
          name                          = "internal"
          private_ip_address_allocation = "Dynamic"
          private_ip_subnet_resource_id = module.spoke1_vnet.subnets["spoke1-subnet"].resource_id
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
