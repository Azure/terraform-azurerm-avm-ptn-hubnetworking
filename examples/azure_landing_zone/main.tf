terraform {
  required_version = ">= 1.9.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.7.0, < 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  regions = {
    primary   = "uksouth"
    secondary = "northeurope"
  }
}

resource "azurerm_resource_group" "hub_rg" {
  for_each = local.regions

  location = each.value
  name     = "rg-hub-${each.value}-${random_pet.rand.id}"
}

resource "random_pet" "rand" {}

module "hub_mesh" {
  source = "../.."
  hub_virtual_networks = {
    primary = {
      name                            = "vnet-hub-primary"
      address_space                   = ["10.0.0.0/22"]
      location                        = local.regions.primary
      resource_group_name             = azurerm_resource_group.hub_rg["primary"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "rt-hub-primary"
      routing_address_space           = ["10.0.0.0/16"]
      firewall = {
        subnet_address_prefix = "10.0.0.0/26"
        name                  = "fw-hub-primary"
        sku_name              = "AZFW_VNet"
        sku_tier              = "Standard"
        zones                 = ["1", "2", "3"]
        default_ip_configuration = {
          public_ip_config = {
            name  = "pip-fw-hub-primary"
            zones = ["1", "2", "3"]
          }
        }
        firewall_policy = {
          name = "fwp-hub-primary"
          dns = {
            proxy_enabled = true
          }
        }
      }
      subnets = {
        bastion = {
          name             = "AzureBastionSubnet"
          address_prefixes = ["10.0.0.64/26"]
          route_table = {
            assign_generated_route_table = false
          }
        }
        gateway = {
          name             = "GatewaySubnet"
          address_prefixes = ["10.0.0.128/27"]
          route_table = {
            assign_generated_route_table = false
          }
        }
        user = {
          name             = "hub-user-subnet"
          address_prefixes = ["10.0.2.0/24"]
        }
      }
    }
    secondary = {
      name                            = "vnet-hub-secondary"
      address_space                   = ["10.1.0.0/22"]
      location                        = local.regions.secondary
      resource_group_name             = azurerm_resource_group.hub_rg["secondary"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "rt-hub-secondary"
      routing_address_space           = ["10.1.0.0/16"]
      firewall = {
        subnet_address_prefix = "10.1.0.0/26"
        name                  = "fw-hub-secondary"
        sku_name              = "AZFW_VNet"
        sku_tier              = "Standard"
        zones                 = ["1", "2", "3"]
        default_ip_configuration = {
          public_ip_config = {
            name  = "pip-fw-hub-secondary"
            zones = ["1", "2", "3"]
          }
        }
        firewall_policy = {
          name = "fwp-hub-secondary"
          dns = {
            proxy_enabled = true
          }
        }
      }
      subnets = {
        bastion = {
          name             = "AzureBastionSubnet"
          address_prefixes = ["10.1.0.64/26"]
          route_table = {
            assign_generated_route_table = false
          }
        }
        gateway = {
          name             = "GatewaySubnet"
          address_prefixes = ["10.1.0.128/27"]
          route_table = {
            assign_generated_route_table = false
          }
        }
        user = {
          name             = "hub-user-subnet"
          address_prefixes = ["10.1.2.0/24"]
        }
      }
    }
  }
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  filename = "key.pem"
  content  = tls_private_key.key.private_key_pem
}

# Spoke 1
resource "azurerm_resource_group" "spoke1" {
  location = local.regions.primary
  name     = "rg-spoke1-${random_pet.rand.id}"
}

module "spoke1_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.7.1"

  name                = "vnet-spoke1-${random_pet.rand.id}"
  address_space       = ["10.0.4.0/24"]
  resource_group_name = azurerm_resource_group.spoke1.name
  location            = azurerm_resource_group.spoke1.location

  peerings = {
    "spoke1-peering" = {
      name                                 = "spoke1-peering"
      remote_virtual_network_resource_id   = module.hub_mesh.virtual_networks["primary"].id
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
      address_prefixes = ["10.0.4.0/28"]
      route_table = {
        id = module.hub_mesh.hub_route_tables_user_subnets["primary"].id
      }
    }
  }
}

module "vm_spoke1" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.15.1"

  location                           = azurerm_resource_group.spoke1.location
  name                               = "vm-spoke1"
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

# Spoke 2

resource "azurerm_resource_group" "spoke2" {
  location = local.regions.secondary
  name     = "rg-spoke2-${random_pet.rand.id}"
}

module "spoke2_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.7.1"

  name                = "vnet-spoke2-${random_pet.rand.id}"
  address_space       = ["10.1.4.0/24"]
  resource_group_name = azurerm_resource_group.spoke2.name
  location            = azurerm_resource_group.spoke2.location

  peerings = {
    "spoke2-peering" = {
      name                                 = "spoke2-peering"
      remote_virtual_network_resource_id   = module.hub_mesh.virtual_networks["secondary"].id
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
      address_prefixes = ["10.1.4.0/28"]
      route_table = {
        id = module.hub_mesh.hub_route_tables_user_subnets["secondary"].id
      }
    }
  }
}

module "vm_spoke2" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.15.1"

  location                           = azurerm_resource_group.spoke2.location
  name                               = "vm-spoke2"
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

output "virtual_networks" {
  value = module.hub_mesh.virtual_networks
}
