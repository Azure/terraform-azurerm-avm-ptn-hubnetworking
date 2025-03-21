<!-- BEGIN_TF_DOCS -->
# Complete example for the hub network module with peering mesh based on the Azure Landing Zones Pattern with Firewall

This shows how to create and manage hub networks with all options enabled to create a multi-region peering mesh hosting sample VMs.

```hcl
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
    primary   = "eastus2"
    secondary = "eastus2"
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
        outbound = {
          name                            = "hub-outbound-subnet"
          address_prefixes                = ["10.0.3.0/24"]
          default_outbound_access_enabled = true
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
  version = "0.18.0"

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
    storage_account_type = "Premium"
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
  version = "0.18.0"

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
    storage_account_type = "Premium"
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

output "firewall" {
  value = module.hub_mesh.firewalls
}

output "firewall_policies" {
  value = module.hub_mesh.firewall_policies
}

output "route_tables_firewall" {
  value = module.hub_mesh.hub_route_tables_firewall
}

output "route_tables_user_subnets" {
  value = module.hub_mesh.hub_route_tables_user_subnets
}

output "resource_groups" {
  value = module.hub_mesh.resource_groups
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9.2)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.0)

- <a name="requirement_local"></a> [local](#requirement\_local) (2.3.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.0)

- <a name="requirement_tls"></a> [tls](#requirement\_tls) (4.0.4)

## Resources

The following resources are used by this module:

- [azurerm_resource_group.hub_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_resource_group.spoke1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_resource_group.spoke2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [local_sensitive_file.private_key](https://registry.terraform.io/providers/hashicorp/local/2.3.0/docs/resources/sensitive_file) (resource)
- [random_pet.rand](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) (resource)
- [tls_private_key.key](https://registry.terraform.io/providers/hashicorp/tls/4.0.4/docs/resources/private_key) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_firewall"></a> [firewall](#output\_firewall)

Description: n/a

### <a name="output_firewall_policies"></a> [firewall\_policies](#output\_firewall\_policies)

Description: n/a

### <a name="output_resource_groups"></a> [resource\_groups](#output\_resource\_groups)

Description: n/a

### <a name="output_route_tables_firewall"></a> [route\_tables\_firewall](#output\_route\_tables\_firewall)

Description: n/a

### <a name="output_route_tables_user_subnets"></a> [route\_tables\_user\_subnets](#output\_route\_tables\_user\_subnets)

Description: n/a

### <a name="output_virtual_networks"></a> [virtual\_networks](#output\_virtual\_networks)

Description: n/a

## Modules

The following Modules are called:

### <a name="module_hub_mesh"></a> [hub\_mesh](#module\_hub\_mesh)

Source: ../..

Version:

### <a name="module_spoke1_vnet"></a> [spoke1\_vnet](#module\_spoke1\_vnet)

Source: Azure/avm-res-network-virtualnetwork/azurerm

Version: 0.7.1

### <a name="module_spoke2_vnet"></a> [spoke2\_vnet](#module\_spoke2\_vnet)

Source: Azure/avm-res-network-virtualnetwork/azurerm

Version: 0.7.1

### <a name="module_vm_spoke1"></a> [vm\_spoke1](#module\_vm\_spoke1)

Source: Azure/avm-res-compute-virtualmachine/azurerm

Version: 0.18.0

### <a name="module_vm_spoke2"></a> [vm\_spoke2](#module\_vm\_spoke2)

Source: Azure/avm-res-compute-virtualmachine/azurerm

Version: 0.18.0

## Usage

Ensure you have Terraform installed and the Azure CLI authenticated to your Azure subscription.

Navigate to the directory containing this configuration and run:

```
terraform init
terraform plan
terraform apply
```
<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

## AVM Versioning Notice

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. The module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to https://semver.org/
<!-- END_TF_DOCS -->