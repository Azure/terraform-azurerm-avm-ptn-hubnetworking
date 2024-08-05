# Terraform Verified Module for multi-hub network architectures

[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/Azure/terraform-azure-hubnetworking.svg)](http://isitmaintained.com/project/Azure/terraform-azure-hubnetworking "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/Azure/terraform-azure-hubnetworking.svg)](http://isitmaintained.com/project/Azure/terraform-azure-hubnetworking "Percentage of issues still open")

This module is designed to simplify the creation of multi-region hub networks in Azure. It will create a number of virtual networks and subnets, and optionally peer them together in a mesh topology with routing.

## Features

- This module will deploy `n` number of virtual networks and subnets.
Optionally, these virtual networks can be peered in a mesh topology.
- A routing address space can be specified for each hub network, this module will then create route tables for the other hub networks and associate them with the subnets.
- Azure Firewall can be deployed in each hub network. This module will configure routing for the AzureFirewallSubnet.

## Example

```terraform
resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = "rg-hub-${var.suffix}"
}

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
```
