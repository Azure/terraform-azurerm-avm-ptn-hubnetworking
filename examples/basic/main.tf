

terraform {
  required_version = ">= 1.9.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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
        sku_name                         = "AZFW_VNet"
        sku_tier                         = "Standard"
        subnet_address_prefix            = "10.0.1.0/24"
        management_subnet_address_prefix = "10.0.2.0/24"
        ip_configurations = {
          primary = {
            name = "primary-ip-config"
            public_ip_config = {
              name  = "pip-hub-primary-1"
              zones = ["1", "2", "3"]
            }
          }
          secondary = {
            name = "secondary-ip-config"
            public_ip_config = {
              name  = "pip-hub-secondary-2"
              zones = ["1", "2", "3"]
            }
          }
        }
        management_ip_configuration = {
          public_ip_config = {
            zones = ["1", "2", "3"]
          }
        }
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
