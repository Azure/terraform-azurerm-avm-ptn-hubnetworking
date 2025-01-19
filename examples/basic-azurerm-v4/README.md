<!-- BEGIN_TF_DOCS -->
# Simple example for the hub network module for azurerm v4

This shows how to create and manage hub networks using the minimal, default values from the module.

```hcl
variable "location" {
  type    = string
  default = "westus2"
}

variable "suffix" {
  type    = string
  default = "test"
}

terraform {
  required_version = ">= 1.9.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 4.0"
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

resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = "rg-hub-${var.suffix}-${random_pet.rand.id}"
}

resource "random_pet" "rand" {}

module "hub" {
  source = "../.."
  hub_virtual_networks = {
    hub = {
      name                            = "hub-${var.suffix}"
      address_space                   = ["10.0.0.0/16"]
      location                        = var.location
      resource_group_name             = azurerm_resource_group.rg.name
      resource_group_creation_enabled = false
      firewall = {
        sku_name              = "AZFW_VNet"
        sku_tier              = "Standard"
        subnet_address_prefix = "10.0.1.0/24"
      }
      subnets = {
        server-subnet = {
          name             = "server-subnet"
          address_prefixes = ["10.0.101.0/24"]
        }
      }
    }
  }
}

output "firewall_id" {
  value = module.hub.firewalls["hub"].id
}

output "firewall_ip_address" {
  value = module.hub.firewalls["hub"].public_ip_address
}

output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "virtual_network_id" {
  value = module.hub.virtual_networks["hub"].id
}

output "subnet_ids" {
  value = module.hub.virtual_networks["hub"].subnet_ids
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9.2)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 4.0)

## Resources

The following resources are used by this module:

- [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [random_pet.rand](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_location"></a> [location](#input\_location)

Description: n/a

Type: `string`

Default: `"westus2"`

### <a name="input_suffix"></a> [suffix](#input\_suffix)

Description: n/a

Type: `string`

Default: `"test"`

## Outputs

The following outputs are exported:

### <a name="output_firewall_id"></a> [firewall\_id](#output\_firewall\_id)

Description: n/a

### <a name="output_firewall_ip_address"></a> [firewall\_ip\_address](#output\_firewall\_ip\_address)

Description: n/a

### <a name="output_resource_group_id"></a> [resource\_group\_id](#output\_resource\_group\_id)

Description: n/a

### <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids)

Description: n/a

### <a name="output_virtual_network_id"></a> [virtual\_network\_id](#output\_virtual\_network\_id)

Description: n/a

## Modules

The following Modules are called:

### <a name="module_hub"></a> [hub](#module\_hub)

Source: ../..

Version:

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