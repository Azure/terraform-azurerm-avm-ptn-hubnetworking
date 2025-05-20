variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "hub_virtual_networks" {
  type = map(object({
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
    tags                            = optional(map(string), {})

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
        threat_intelligence_mode = optional(string, "Alert")
        private_ip_ranges        = optional(list(string))
        threat_intelligence_allowlist = optional(object({
          fqdns        = optional(set(string))
          ip_addresses = optional(set(string))
        }))
      }))
    }))
  }))
  default     = {}
  description = <<DESCRIPTION
A map of the hub virtual networks to create. The map key is an arbitrary value to avoid Terraform's restriction that map keys must be known at plan time.

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
  - `sku_tier` - The tier of the SKU to use for the Azure Firewall. Possible values include `Basic`, ``Standard`, `Premium`.
  - `subnet_address_prefix` - The IPv4 address prefix to use for the Azure Firewall subnet in CIDR format. Needs to be a part of the virtual network's address space.
  - `subnet_default_outbound_access_enabled` - (Optional) Should the default outbound access be enabled for the Azure Firewall subnet? Default `false`.
  - `firewall_policy_id` - (Optional) The resource id of the Azure Firewall Policy to associate with the Azure Firewall.
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
DESCRIPTION
  nullable    = false

  # Validate that there is at least 1 hub network defined
  validation {
    condition     = length(var.hub_virtual_networks) > 0
    error_message = "At least one hub virtual network must be defined."
  }
}
