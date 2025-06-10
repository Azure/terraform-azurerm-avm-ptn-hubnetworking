<!-- BEGIN_TF_DOCS -->
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

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.3.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.116, < 5.0)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (~> 0.3)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.6)

## Resources

The following resources are used by this module:

- [azurerm_management_lock.rg_lock](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route.firewall_default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) (resource)
- [azurerm_route.firewall_mesh](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) (resource)
- [azurerm_route.user_subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) (resource)
- [modtm_telemetry.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/resources/telemetry) (resource)
- [random_uuid.telemetry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) (resource)
- [azurerm_client_config.telemetry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [modtm_module_source.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/data-sources/module_source) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see https://aka.ms/avm/telemetryinfo.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_hub_virtual_networks"></a> [hub\_virtual\_networks](#input\_hub\_virtual\_networks)

Description: A map of the hub virtual networks to create. The map key is an arbitrary value to avoid Terraform's restriction that map keys must be known at plan time.

### Mandatory fields

- `name` - The name of the Virtual Network.
- `address_space` - A list of IPv4 address spaces that are used by this virtual network in CIDR format, e.g. `["192.168.0.0/24"]`.
- `location` - The Azure location where the virtual network should be created.
- `resource_group_name` - The name of the resource group in which the virtual network should be created.

### Optional fields

- `bgp_community` - The BGP community associated with the virtual network.
- `ddos_protection_plan_id` - The ID of the DDoS protection plan associated with the virtual network.
- `dns_servers` - A list of DNS servers IP addresses for the virtual network.
- `flow_timeout_in_minutes` - The flow timeout in minutes for the virtual network. Default `4`.
- `mesh_peering_enabled` - Should the virtual network be peered to other hub networks with this flag enabled? Default `true`.
- `peering_names` - A map of the names of the peering connections to create between this virtual network and other hub networks. The key is the key of the peered hub network, and the value is the name of the peering connection.
- `resource_group_creation_enabled` - Should the resource group for this virtual network be created by this module? Default `true`.
- `resource_group_lock_enabled` - Should the resource group for this virtual network be locked? Default `true`.
- `resource_group_lock_name` - The name of the resource group lock.
- `resource_group_tags` - A map of tags to apply to the resource group.
- `route_table_name_firewall` - The name of the route table to create for the firewall routes. Default `route-{vnetname}`.
- `route_table_name_user_subnets` - The name of the route table to create for the user subnet routes. Default `route-{vnetname}`.
- `routing_address_space` - A list of IPv4 address spaces in CIDR format that are used for routing to this hub, e.g. `["192.168.0.0","172.16.0.0/12"]`.
- `hub_router_ip_address` - If not using Azure Firewall, this is the IP address of the hub router. This is used to create route table entries for other hub networks.
- `tags` - A map of tags to apply to the virtual network.

#### Route table entries

- `route_table_entries_firewall` - (Optional) A set of additional route table entries to add to the Firewall route table for this hub network. Default empty `[]`. The value is an object with the following fields:
  - `name` - The name of the route table entry.
  - `address_prefix` - The address prefix to match for this route table entry.
  - `next_hop_type` - The type of the next hop. Possible values include `Internet`, `VirtualAppliance`, `VirtualNetworkGateway`, `VnetLocal`, `None`.
  - `has_bgp_override` - Should the BGP override be enabled for this route table entry? Default `false`.
  - `next_hop_ip_address` - The IP address of the next hop. Required if `next_hop_type` is `VirtualAppliance`.

- `route_table_entries_user_subnets` - (Optional) A set of additional route table entries to add to the User Subnets route table for this hub network. Default empty `[]`. The value is an object with the following fields:
  - `name` - The name of the route table entry.
  - `address_prefix` - The address prefix to match for this route table entry.
  - `next_hop_type` - The type of the next hop. Possible values include `Internet`, `VirtualAppliance`, `VirtualNetworkGateway`, `VnetLocal`, `None`.
  - `has_bgp_override` - Should the BGP override be enabled for this route table entry? Default `false`.
  - `next_hop_ip_address` - The IP address of the next hop. Required if `next_hop_type` is `VirtualAppliance`.

#### Subnets

- `subnets` - (Optional) A map of subnets to create in the virtual network. The value is an object with the following fields:
  - `name` - The name of the subnet.
  - `address_prefixes` - The IPv4 address prefixes to use for the subnet in CIDR format.
  - `nat_gateway` - (Optional) An object with the following fields:
    - `id` - The ID of the NAT Gateway which should be associated with the Subnet. Changing this forces a new resource to be created.
  - `network_security_group` - (Optional) An object with the following fields:
    - `id` - The ID of the Network Security Group which should be associated with the Subnet. Changing this forces a new association to be created.
  - `private_endpoint_network_policies_enabled` - (Optional) Enable or Disable network policies for the private endpoint on the subnet. Setting this to true will Enable the policy and setting this to false will Disable the policy. Defaults to true.
  - `private_link_service_network_policies_enabled` - (Optional) Enable or Disable network policies for the private link service on the subnet. Setting this to true will Enable the policy and setting this to false will Disable the policy. Defaults to true.
  - `route_table` - (Optional) An object with the following fields which are mutually exclusive, choose either an external route table or the generated route table:
    - `id` - The ID of the Route Table which should be associated with the Subnet. Changing this forces a new association to be created.
    - `assign_generated_route_table` - (Optional) Should the Route Table generated by this module be associated with this Subnet? Default `true`.
  - `service_endpoints` - (Optional) The list of Service endpoints to associate with the subnet.
  - `service_endpoint_policy_ids` - (Optional) The list of Service Endpoint Policy IDs to associate with the subnet.
  - `service_endpoint_policy_assignment_enabled` - (Optional) Should the Service Endpoint Policy be assigned to the subnet? Default `true`.
  - `delegation` - (Optional) An object with the following fields:
    - `name` - The name of the delegation.
    - `service_delegation` - An object with the following fields:
      - `name` - The name of the service delegation.
      - `actions` - A list of actions that should be delegated, the list is specific to the service being delegated.
  - `default_outbound_access_enabled` - (Optional) Should the default outbound access be enabled for the subnet? Default `false`.

#### Azure Firewall

- `firewall` - (Optional) An object with the following fields:
  - `sku_name` - The name of the SKU to use for the Azure Firewall. Possible values include `AZFW_Hub`, `AZFW_VNet`.
  - `sku_tier` - The tier of the SKU to use for the Azure Firewall. Possible values include `Basic`, `Standard`, `Premium`.
  - `subnet_address_prefix` - The IPv4 address prefix to use for the Azure Firewall subnet in CIDR format. Needs to be a part of the virtual network's address space.
  - `subnet_default_outbound_access_enabled` - (Optional) Should the default outbound access be enabled for the Azure Firewall subnet? Default `false`.
  - `firewall_policy_id` - (Optional) The resource id of the Azure Firewall Policy to associate with the Azure Firewall.
  - `management_ip_enabled` - (Optional) Should the Azure Firewall management IP be enabled? Default `true`.
  - `management_subnet_address_prefix` - (Optional) The IPv4 address prefix to use for the Azure Firewall management subnet in CIDR format. Needs to be a part of the virtual network's address space.
  - `management_subnet_default_outbound_access_enabled` - (Optional) Should the default outbound access be enabled for the Azure Firewall management subnet? Default `false`.
  - `name` - (Optional) The name of the firewall resource. If not specified will use `afw-{vnetname}`.
  - `private_ip_ranges` - (Optional) A list of private IP ranges to use for the Azure Firewall, to which the firewall will not NAT traffic. If not specified will use RFC1918.
  - `subnet_route_table_id` = (Optional) The resource id of the Route Table which should be associated with the Azure Firewall subnet. If not specified the module will assign the generated route table.
  - `tags` - (Optional) A map of tags to apply to the Azure Firewall. If not specified
  - `zones` - (Optional) A list of availability zones to use for the Azure Firewall. If not specified will be `null`.
  - `default_ip_configuration` - (Optional) An object with the following fields. If not specified the defaults below will be used:
    - `name` - (Optional) The name of the default IP configuration. If not specified will use `default`.
    - `public_ip_config` - (Optional) An object with the following fields:
      - `name` - (Optional) The name of the public IP configuration. If not specified will use `pip-afw-{vnetname}`.
      - `zones` - (Optional) A list of availability zones to use for the public IP configuration. If not specified will be `null`.
      - `ip_version` - (Optional) The IP version to use for the public IP configuration. Possible values include `IPv4`, `IPv6`. If not specified will be `IPv4`.
      - `sku_tier` - (Optional) The SKU tier to use for the public IP configuration. Possible values include `Regional`, `Global`. If not specified will be `Regional`.
  - `management_ip_configuration` - (Optional) An object with the following fields. If not specified the defaults below will be used:
    - `name` - (Optional) The name of the management IP configuration. If not specified will use `defaultMgmt`.
    - `public_ip_config` - (Optional) An object with the following fields:
      - `name` - (Optional) The name of the public IP configuration. If not specified will use `pip-afw-mgmt-<Map Key>`.
      - `zones` - (Optional) A list of availability zones to use for the public IP configuration. If not specified will be `null`.
      - `ip_version` - (Optional) The IP version to use for the public IP configuration. Possible values include `IPv4`, `IPv6`. If not specified will be `IPv4`.
      - `sku_tier` - (Optional) The SKU tier to use for the public IP configuration. Possible values include `Regional`, `Global`. If not specified will be `Regional`.
  - `firewall_policy` - (Optional) An object with the following fields. Cannot be used with `firewall_policy_id`. If not specified the defaults below will be used:
    - `name` - (Optional) The name of the firewall policy. If not specified will use `afw-policy-{vnetname}`.
    - `sku` - (Optional) The SKU to use for the firewall policy. Possible values include `Standard`, `Premium`.
    - `auto_learn_private_ranges_enabled` - (Optional) Should the firewall policy automatically learn private ranges? Default `false`.
    - `base_policy_id` - (Optional) The resource id of the base policy to use for the firewall policy.
    - `dns` - (Optional) An object with the following fields:
      - `proxy_enabled` - (Optional) Should the DNS proxy be enabled for the firewall policy? Default `false`.
      - `servers` - (Optional) A list of DNS server IP addresses for the firewall policy.
    - `threat_intelligence_mode` - (Optional) The threat intelligence mode for the firewall policy. Possible values include `Alert`, `Deny`, `Off`.
    - `private_ip_ranges` - (Optional) A list of private IP ranges to use for the firewall policy.
    - `threat_intelligence_allowlist` - (Optional) An object with the following fields:
      - `fqdns` - (Optional) A set of FQDNs to allowlist for threat intelligence.
      - `ip_addresses` - (Optional) A set of IP addresses to allowlist for threat intelligence.

Type:

```hcl
map(object({
    name                            = string
    address_space                   = list(string)
    location                        = string
    resource_group_name             = string
    route_table_name_firewall       = optional(string)
    route_table_name_user_subnets   = optional(string)
    bgp_community                   = optional(string)
    ddos_protection_plan_id         = optional(string)
    dns_servers                     = optional(list(string))
    flow_timeout_in_minutes         = optional(number, 4)
    mesh_peering_enabled            = optional(bool, true)
    peering_names                   = optional(map(string))
    resource_group_creation_enabled = optional(bool, true)
    resource_group_lock_enabled     = optional(bool, true)
    resource_group_lock_name        = optional(string)
    resource_group_tags             = optional(map(string))
    routing_address_space           = optional(list(string), [])
    hub_router_ip_address           = optional(string)
    tags                            = optional(map(string))

    route_table_entries_firewall = optional(set(object({
      name           = string
      address_prefix = string
      next_hop_type  = string

      has_bgp_override    = optional(bool, false)
      next_hop_ip_address = optional(string)
    })), [])

    route_table_entries_user_subnets = optional(set(object({
      name           = string
      address_prefix = string
      next_hop_type  = string

      has_bgp_override    = optional(bool, false)
      next_hop_ip_address = optional(string)
    })), [])

    subnets = optional(map(object(
      {
        name             = string
        address_prefixes = list(string)
        nat_gateway = optional(object({
          id = string
        }))
        network_security_group = optional(object({
          id = string
        }))
        private_endpoint_network_policies_enabled     = optional(bool, true)
        private_link_service_network_policies_enabled = optional(bool, true)
        route_table = optional(object({
          id                           = optional(string)
          assign_generated_route_table = optional(bool, true)
        }))
        service_endpoints           = optional(set(string))
        service_endpoint_policy_ids = optional(set(string))
        delegations = optional(list(
          object(
            {
              name = string
              service_delegation = object({
                name    = string
                actions = optional(list(string))
              })
            }
          )
        ))
        default_outbound_access_enabled = optional(bool, false)
      }
    )), {})

    firewall = optional(object({
      sku_name                                          = string
      sku_tier                                          = string
      subnet_address_prefix                             = string
      subnet_default_outbound_access_enabled            = optional(bool, false)
      firewall_policy_id                                = optional(string, null)
      management_ip_enabled                             = optional(bool, true)
      management_subnet_address_prefix                  = optional(string, null)
      management_subnet_default_outbound_access_enabled = optional(bool, false)
      name                                              = optional(string)
      private_ip_ranges                                 = optional(list(string))
      subnet_route_table_id                             = optional(string)
      tags                                              = optional(map(string))
      zones                                             = optional(list(string))
      default_ip_configuration = optional(object({
        name = optional(string)
        public_ip_config = optional(object({
          ip_version = optional(string, "IPv4")
          name       = optional(string)
          sku_tier   = optional(string, "Regional")
          zones      = optional(set(string))
        }))
      }))
      management_ip_configuration = optional(object({
        name = optional(string)
        public_ip_config = optional(object({
          ip_version = optional(string, "IPv4")
          name       = optional(string)
          sku_tier   = optional(string, "Regional")
          zones      = optional(set(string))
        }))
      }))
      firewall_policy = optional(object({
        name                              = optional(string)
        sku                               = optional(string, "Standard")
        auto_learn_private_ranges_enabled = optional(bool)
        base_policy_id                    = optional(string)
        dns = optional(object({
          proxy_enabled = optional(bool, false)
          servers       = optional(list(string))
        }))
        explicit_proxy = optional(object({
          enable_pac_file = optional(bool)
          enabled         = optional(bool)
          http_port       = optional(number)
          https_port      = optional(number)
          pac_file        = optional(string)
          pac_file_port   = optional(number)
        }))
        identity = optional(object({
          type         = string
          identity_ids = optional(set(string))
        }))
        insights = optional(object({
          default_log_analytics_workspace_id = string
          enabled                            = bool
          retention_in_days                  = optional(number)
          log_analytics_workspace = optional(list(object({
            firewall_location = string
            id                = string
          })))
        }))
        intrusion_detection = optional(object({
          mode           = optional(string)
          private_ranges = optional(list(string))
          signature_overrides = optional(list(object({
            id    = optional(string)
            state = optional(string)
          })))
          traffic_bypass = optional(list(object({
            description           = optional(string)
            destination_addresses = optional(set(string))
            destination_ip_groups = optional(set(string))
            destination_ports     = optional(set(string))
            name                  = string
            protocol              = string
            source_addresses      = optional(set(string))
            source_ip_groups      = optional(set(string))
          })))
        }))
        private_ip_ranges        = optional(list(string))
        sql_redirect_allowed     = optional(bool, false)
        threat_intelligence_mode = optional(string, "Alert")

        threat_intelligence_allowlist = optional(object({
          fqdns        = optional(set(string))
          ip_addresses = optional(set(string))
        }))
        tls_certificate = optional(object({
          key_vault_secret_id = string
          name                = string
        }))
      }))
    }))
  }))
```

Default: `{}`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optional) Tags of the resource.

Type: `map(string)`

Default: `null`

## Outputs

The following outputs are exported:

### <a name="output_firewall_policies"></a> [firewall\_policies](#output\_firewall\_policies)

Description: A curated output of the firewall policies created by this module.

### <a name="output_firewalls"></a> [firewalls](#output\_firewalls)

Description: A curated output of the firewalls created by this module.

### <a name="output_hub_route_tables_firewall"></a> [hub\_route\_tables\_firewall](#output\_hub\_route\_tables\_firewall)

Description: A curated output of the route tables created by this module.

### <a name="output_hub_route_tables_user_subnets"></a> [hub\_route\_tables\_user\_subnets](#output\_hub\_route\_tables\_user\_subnets)

Description: A curated output of the route tables created by this module.

### <a name="output_name"></a> [name](#output\_name)

Description: The names of the hub virtual networks.

### <a name="output_resource_groups"></a> [resource\_groups](#output\_resource\_groups)

Description: A curated output of the resource groups created by this module.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The resource IDs of the hub virtual networks.

### <a name="output_test"></a> [test](#output\_test)

Description: n/a

### <a name="output_virtual_networks"></a> [virtual\_networks](#output\_virtual\_networks)

Description: A curated output of the virtual networks created by this module.

## Modules

The following Modules are called:

### <a name="module_fw_default_ips"></a> [fw\_default\_ips](#module\_fw\_default\_ips)

Source: Azure/avm-res-network-publicipaddress/azurerm

Version: 0.2.0

### <a name="module_fw_management_ips"></a> [fw\_management\_ips](#module\_fw\_management\_ips)

Source: Azure/avm-res-network-publicipaddress/azurerm

Version: 0.2.0

### <a name="module_fw_policies"></a> [fw\_policies](#module\_fw\_policies)

Source: Azure/avm-res-network-firewallpolicy/azurerm

Version: 0.3.3

### <a name="module_hub_firewalls"></a> [hub\_firewalls](#module\_hub\_firewalls)

Source: Azure/avm-res-network-azurefirewall/azurerm

Version: 0.3.0

### <a name="module_hub_routing_firewall"></a> [hub\_routing\_firewall](#module\_hub\_routing\_firewall)

Source: Azure/avm-res-network-routetable/azurerm

Version: 0.3.1

### <a name="module_hub_routing_user_subnets"></a> [hub\_routing\_user\_subnets](#module\_hub\_routing\_user\_subnets)

Source: Azure/avm-res-network-routetable/azurerm

Version: 0.3.1

### <a name="module_hub_virtual_network_peering"></a> [hub\_virtual\_network\_peering](#module\_hub\_virtual\_network\_peering)

Source: Azure/avm-res-network-virtualnetwork/azurerm//modules/peering

Version: 0.7.1

### <a name="module_hub_virtual_network_subnets"></a> [hub\_virtual\_network\_subnets](#module\_hub\_virtual\_network\_subnets)

Source: Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet

Version: 0.7.1

### <a name="module_hub_virtual_networks"></a> [hub\_virtual\_networks](#module\_hub\_virtual\_networks)

Source: Azure/avm-res-network-virtualnetwork/azurerm

Version: 0.7.1

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->