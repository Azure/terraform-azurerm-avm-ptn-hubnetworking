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
