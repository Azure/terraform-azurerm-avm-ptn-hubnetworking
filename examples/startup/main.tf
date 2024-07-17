locals {
  regions = toset(["eastus", "eastus2", "westus2"])
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
        tags = {
          afw = "testing"
        }
        threat_intel_mode = "Alert"
        management_ip_configuration = {
          public_ip_config = {
            name       = "piptest-mgmt-afw-ip2"
            ip_version = "IPv4"
            sku_tier   = "Regional"
          }
        }
        private_ip_ranges = ["10.0.30.0/24"]
      }
      subnets = {
        hub1-subnet1 = {
          name             = "hub1-subnet1"
          address_prefixes = ["10.0.101.0/24"]
          delegations = [{
            name = "hub1-subnet1-delegation"
            service_delegation = {
              name    = "Microsoft.ContainerInstance/containerGroups"
              actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
            }
          }]
        }
        hub1-subnet2 = {
          name                                      = "hub1-subnet2"
          address_prefixes                          = ["10.0.102.0/24"]
          private_endpoint_network_policies_enabled = false
        }
        testing = {
          name                         = "hub1-test"
          address_prefixes             = ["10.0.103.0/24"]
          assign_generated_route_table = false
        }
      }
    }
    eastus2-hub = {
      name                            = "eastus2-hub"
      address_space                   = ["10.1.0.0/16"]
      location                        = "eastus2"
      resource_group_name             = azurerm_resource_group.hub_rg["eastus2"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = false
      route_table_name                = "contoso-eastus2-hub-rt2"
      routing_address_space           = ["10.1.0.0/16", "192.168.1.0/24"]
      firewall = {
        sku_name              = "AZFW_VNet"
        sku_tier              = "Standard"
        name                  = "testing-afw"
        subnet_address_prefix = "10.1.1.0/24"
        firewall_policy_id    = azurerm_firewall_policy.fwpolicy.id
        threat_intel_mode     = "Deny"
      }
      route_table_entries = [{
        name           = "testing1"
        address_prefix = "10.1.10.0/24"
        next_hop_type  = "VirtualAppliance"

        has_bgp_override    = false
        next_hop_ip_address = "10.1.0.4"
        }, {
        name           = "testing2"
        address_prefix = "10.1.20.0/24"
        next_hop_type  = "VirtualAppliance"

        has_bgp_override    = false
        next_hop_ip_address = "10.1.0.4"
      }]
    }
    westus2-hub = {
      name                            = "westus2-hub"
      address_space                   = ["10.2.0.0/16"]
      location                        = "westus2"
      resource_group_name             = azurerm_resource_group.hub_rg["westus2"].name
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "contoso-westus2-hub-rt2"
      routing_address_space           = ["10.2.0.0/16", "192.168.2.0/24"]
      hub_router_ip_address           = "10.2.101.4"
      subnets = {
        hub1-subnet1 = {
          name             = "hub3-subnet1"
          address_prefixes = ["10.2.101.0/24"]
        }
      }
    }
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.allow_internal]
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

resource "azurerm_firewall_policy" "fwpolicy" {
  location            = azurerm_resource_group.fwpolicy.location
  name                = "allow-internal"
  resource_group_name = azurerm_resource_group.fwpolicy.name
  sku                 = "Standard"
}

resource "azurerm_firewall_policy_rule_collection_group" "allow_internal" {
  firewall_policy_id = azurerm_firewall_policy.fwpolicy.id
  name               = "allow-rfc1918"
  priority           = 100

  network_rule_collection {
    action   = "Allow"
    name     = "rfc1918"
    priority = 100

    rule {
      destination_ports     = ["*"]
      name                  = "rfc1918"
      protocols             = ["Any"]
      destination_addresses = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    }
  }
}
