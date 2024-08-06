locals {
  regions = toset(["eastus", "eastus2"])
}

resource "azurerm_resource_group" "hub_rg" {
  for_each = local.regions

  location = each.value
  name     = "hubandspokedemo-hub-${each.value}-${random_pet.rand.id}"
}

resource "random_pet" "rand" {}

module "hub_mesh" {
  source = "../.."
  hub_virtual_networks = {
    eastus-hub = {
      name                            = "eastus-hub"
      address_space                   = ["10.0.0.0/16"]
      location                        = "eastus"
      resource_group_name             = azurerm_resource_group.hub_rg["eastus"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "contosohotel-eastus-hub-rt2"
      routing_address_space           = ["10.0.0.0/16", "192.168.0.0/24"]
      firewall = {
        sku_name              = "AZFW_VNet"
        sku_tier              = "Standard"
        subnet_address_prefix = "10.0.1.0/24"
        firewall_policy_id    = module.fw_policy.resource_id
      }
    }
    eastus2-hub = {
      name                            = "eastus2-hub"
      address_space                   = ["10.1.0.0/16"]
      location                        = "eastus2"
      resource_group_name             = azurerm_resource_group.hub_rg["eastus2"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "contoso-eastus2-hub-rt2"
      routing_address_space           = ["10.1.0.0/16", "192.168.1.0/24"]
      firewall = {
        sku_name              = "AZFW_VNet"
        sku_tier              = "Standard"
        subnet_address_prefix = "10.1.1.0/24"
        firewall_policy_id    = module.fw_policy.resource_id
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
  location = "eastus"
  name     = "fwpolicy-${random_pet.rand.id}"
}

module "fw_policy" {
  source  = "Azure/avm-res-network-firewallpolicy/azurerm"
  version = "0.2.3"

  location            = azurerm_resource_group.fwpolicy.location
  name                = "allow-internal"
  resource_group_name = azurerm_resource_group.fwpolicy.name
  firewall_policy_sku = "Standard"
}

module "fw_policy_rule_collection_groups" {
  source  = "Azure/avm-res-network-firewallpolicy/azurerm//modules/rule_collection_groups"
  version = "0.2.3"

  firewall_policy_rule_collection_group_firewall_policy_id = module.fw_policy.resource_id
  firewall_policy_rule_collection_group_name               = "allow-rfc1918"
  firewall_policy_rule_collection_group_priority           = 100

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
}
