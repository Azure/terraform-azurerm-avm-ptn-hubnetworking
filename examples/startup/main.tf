terraform {
  required_version = ">= 1.9.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
    primary-hub = {
      name                            = "primary"
      address_space                   = ["10.0.0.0/16"]
      location                        = local.regions.primary
      resource_group_name             = azurerm_resource_group.hub_rg["primary"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "rt-hub-primary"
      routing_address_space           = ["10.0.0.0/16", "192.168.0.0/24"]
      firewall = {
        sku_name                         = "AZFW_VNet"
        sku_tier                         = "Standard"
        subnet_address_prefix            = "10.0.1.0/24"
        management_subnet_address_prefix = "10.0.2.0/24"
        firewall_policy_id               = module.fw_policy.resource_id
        default_ip_configuration = {
          public_ip_config = {
            zones = ["1", "2", "3"]
          }
        }
        management_ip_configuration = {
          public_ip_config = {
            zones = ["1", "2", "3"]
          }
        }
      }
      subnets = {
        test-subnet = {
          name             = "user-test-subnet"
          address_prefixes = ["10.0.101.0/24"]
        }
      }
    }
    secondary-hub = {
      name                            = "secondary-hub"
      address_space                   = ["10.1.0.0/16"]
      location                        = local.regions.secondary
      resource_group_name             = azurerm_resource_group.hub_rg["secondary"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "rt-hub-secondary"
      routing_address_space           = ["10.1.0.0/16", "192.168.1.0/24"]
      firewall = {
        sku_name                         = "AZFW_VNet"
        sku_tier                         = "Standard"
        subnet_address_prefix            = "10.1.1.0/24"
        management_subnet_address_prefix = "10.1.2.0/24"
        firewall_policy_id               = module.fw_policy.resource_id
        default_ip_configuration = {
          public_ip_config = {
            zones = ["1", "2", "3"]
          }
        }
        management_ip_configuration = {
          public_ip_config = {
            zones = ["1", "2", "3"]
          }
        }
      }
      subnets = {
        test-subnet = {
          name             = "user-test-subnet"
          address_prefixes = ["10.1.101.0/24"]
        }
      }
    }
  }

  depends_on = [module.fw_policy_rule_collection_groups]
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  filename = "key.pem"
  content  = tls_private_key.key.private_key_pem
}

resource "azurerm_resource_group" "fwpolicy" {
  location = local.regions.primary
  name     = "rg-hub-fwp-${random_pet.rand.id}"
}

module "fw_policy" {
  source  = "Azure/avm-res-network-firewallpolicy/azurerm"
  version = "0.3.2"

  location            = azurerm_resource_group.fwpolicy.location
  name                = "allow-internal"
  resource_group_name = azurerm_resource_group.fwpolicy.name
  firewall_policy_sku = "Standard"
}

module "fw_policy_rule_collection_groups" {
  source  = "Azure/avm-res-network-firewallpolicy/azurerm//modules/rule_collection_groups"
  version = "0.3.2"

  firewall_policy_rule_collection_group_firewall_policy_id = module.fw_policy.resource_id
  firewall_policy_rule_collection_group_name               = "allow-rfc1918"
  firewall_policy_rule_collection_group_network_rule_collection = [{
    action   = "Allow"
    name     = "rfc1918"
    priority = 100

    rule = [{
      destination_ports     = ["*"]
      name                  = "rfc1918"
      protocols             = ["Any"]
      destination_addresses = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    }]
  }]
  firewall_policy_rule_collection_group_priority = 100
}

# Spoke 1
resource "azurerm_resource_group" "spoke1" {
  location = local.regions.primary
  name     = "rg-spoke1-${random_pet.rand.id}"
}

module "spoke1_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.7.1"

  address_space       = ["192.168.0.0/24"]
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  name                = "vnet-spoke1-${random_pet.rand.id}"
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
  version = "0.3.1"

  location            = azurerm_resource_group.spoke1.location
  name                = "rt-spoke1"
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
  version = "0.18.0"

  location = azurerm_resource_group.spoke1.location
  name     = "vm-spoke1"
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
  resource_group_name = azurerm_resource_group.spoke1.name
  zone                = 1
  admin_ssh_keys = [{
    public_key = tls_private_key.key.public_key_openssh
    username   = "adminuser"
  }]
  admin_username                     = "adminuser"
  generate_admin_password_or_ssh_key = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  os_type  = "linux"
  sku_size = "Standard_B1s"
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

  address_space       = ["192.168.1.0/24"]
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  name                = "vnet-spoke2-${random_pet.rand.id}"
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
  name                = "rt-spoke2"
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
  version = "0.18.0"

  location = azurerm_resource_group.spoke2.location
  name     = "vm-spoke2"
  network_interfaces = {
    network_interface_1 = {
      name = "nic"
      ip_configurations = {
        ip_configurations_1 = {
          name                          = "nic"
          private_ip_address_allocation = "Dynamic"
          private_ip_subnet_resource_id = module.spoke2_vnet.subnets["spoke2-subnet"].resource_id
        }
      }
    }
  }
  resource_group_name = azurerm_resource_group.spoke2.name
  zone                = 1
  admin_ssh_keys = [{
    public_key = tls_private_key.key.public_key_openssh
    username   = "adminuser"
  }]
  admin_username                     = "adminuser"
  generate_admin_password_or_ssh_key = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  os_type  = "linux"
  sku_size = "Standard_B1s"
  source_image_reference = {
    offer     = "0001-com-ubuntu-server-jammy"
    publisher = "Canonical"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

