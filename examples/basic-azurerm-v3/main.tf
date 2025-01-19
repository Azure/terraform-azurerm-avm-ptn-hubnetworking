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
