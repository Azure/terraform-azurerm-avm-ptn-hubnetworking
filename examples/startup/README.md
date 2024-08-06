<!-- BEGIN_TF_DOCS -->
# Complete example for the AVM hub network module with peering mesh

This shows how to create and manage hub networks with AVMs with all options enabled to create a multi-region peering mesh hosting sample VMs.

```hcl
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
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9.2)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>=3.7.0, < 4.0)

- <a name="requirement_local"></a> [local](#requirement\_local) (2.3.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.0)

- <a name="requirement_tls"></a> [tls](#requirement\_tls) (4.0.4)

## Resources

The following resources are used by this module:

- [azurerm_resource_group.fwpolicy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
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

### <a name="output_spoke2_pip"></a> [spoke2\_pip](#output\_spoke2\_pip)

Description: n/a

## Modules

The following Modules are called:

### <a name="module_fw_policy"></a> [fw\_policy](#module\_fw\_policy)

Source: Azure/avm-res-network-firewallpolicy/azurerm

Version: 0.2.3

### <a name="module_fw_policy_rule_collection_groups"></a> [fw\_policy\_rule\_collection\_groups](#module\_fw\_policy\_rule\_collection\_groups)

Source: Azure/avm-res-network-firewallpolicy/azurerm//modules/rule_collection_groups

Version: 0.2.3

### <a name="module_hub_mesh"></a> [hub\_mesh](#module\_hub\_mesh)

Source: ../..

Version:

### <a name="module_route_table_spoke1"></a> [route\_table\_spoke1](#module\_route\_table\_spoke1)

Source: Azure/avm-res-network-routetable/azurerm

Version: 0.2.0

### <a name="module_route_table_spoke_2"></a> [route\_table\_spoke\_2](#module\_route\_table\_spoke\_2)

Source: Azure/avm-res-network-routetable/azurerm

Version: 0.2.0

### <a name="module_spoke1_vnet"></a> [spoke1\_vnet](#module\_spoke1\_vnet)

Source: Azure/avm-res-network-virtualnetwork/azurerm

Version: 0.2.3

### <a name="module_spoke2_vnet"></a> [spoke2\_vnet](#module\_spoke2\_vnet)

Source: Azure/avm-res-network-virtualnetwork/azurerm

Version: 0.2.3

### <a name="module_vm_spoke1"></a> [vm\_spoke1](#module\_vm\_spoke1)

Source: Azure/avm-res-compute-virtualmachine/azurerm

Version: 0.15.1

### <a name="module_vm_spoke2"></a> [vm\_spoke2](#module\_vm\_spoke2)

Source: Azure/avm-res-compute-virtualmachine/azurerm

Version: 0.15.1

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