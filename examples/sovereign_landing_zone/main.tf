variable "default_prefix" {
  type        = string
  default     = "mcfs"
  description = "Prefix added to all Azure resources created by the SLZ. (e.g 'mcfs')|2|"
}

variable "deploy_hub_network" {
  type        = bool
  default     = true
  description = "Toggles deployment of the hub VNET. True to deploy, otherwise false. (e.g true)|10|"
}

variable "hub_network_address_prefix" {
  type        = string
  default     = "10.20.0.0/16"
  description = "CIDR range for the hub VNET. (e.g '10.20.0.0/16')|14|"
}

variable "tags" {
  description = "A map of tags to add to the resources"
  type        = map(string)
  default     = {}
}

variable "enable_firewall" {
  description = "Enable the firewall"
  type        = bool
  default     = true
}

variable "az_firewall_policies_enabled" {
  type        = bool
  default     = true
  description = "Set this to true for the initial deployment as one firewall policy is required. Set this to false in subsequent deployments if using custom policies. (e.g true)|13|"
}

variable "starter_locations" {
  description = "The locations to deploy the resources"
  type        = list(string)
  default     = ["uksouth"]
}

variable "use_premium_firewall" {
  type        = bool
  default     = true
  description = "Toggles deployment of the Premium SKU for Azure Firewall and only used if enable_Firewall is enabled. True to use Premium SKU, otherwise false. (e.g true)|12|"
}

variable "custom_subnets" {
  type = map(object({
    name                   = string
    address_prefixes       = string
    networkSecurityGroupId = optional(string, "")
    routeTableId           = optional(string, "")
  }))
  default = {
    AzureBastionSubnet = {
      name                   = "AzureBastionSubnet"
      address_prefixes       = "10.20.15.0/24"
      networkSecurityGroupId = ""
      routeTableId           = ""
    }
    GatewaySubnet = {
      name                   = "GatewaySubnet"
      address_prefixes       = "10.20.252.0/24"
      networkSecurityGroupId = ""
      routeTableId           = ""
    }
    AzureFirewallSubnet = {
      name                   = "AzureFirewallSubnet"
      address_prefixes       = "10.20.254.0/24"
      networkSecurityGroupId = ""
      routeTableId           = ""
    }
  }
  description = "List of other subnets to deploy on the hub VNET and their CIDR ranges. |15|"
}

module "hub_rg" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  version  = "0.1.0"
  location = var.starter_locations[0]
  name     = "rg-hub-${var.default_prefix}-${var.starter_locations[0]}-${local.default_postfix}"
}

resource "random_pet" "this" {}

locals {
  ddos_protection_plan_id = ""
  default_postfix = random_pet.this.id
}

module "firewall_policy" {
  source  = "Azure/avm-res-network-firewallpolicy/azurerm"
  version = "0.2.3"

  name                = "fwp-hub-${var.default_prefix}-${var.starter_locations[0]}-${local.default_postfix}"
  location            = var.starter_locations[0]
  resource_group_name = module.hub_rg.name
  tags                = var.tags

  depends_on = [module.hub_rg]
}

module "hubnetworks" {
  source = "../.."
  count   = var.deploy_hub_network ? 1 : 0
  hub_virtual_networks = {
    hub = {
      name                            = "vnet-hub-${var.default_prefix}-${var.starter_locations[0]}-${local.default_postfix}"
      address_space                   = [var.hub_network_address_prefix]
      location                        = var.starter_locations[0]
      resource_group_name             = module.hub_rg.name
      resource_group_tags             = var.tags
      resource_group_creation_enabled = false
      resource_group_lock_enabled     = false
      mesh_peering_enabled            = true
      route_table_name                = "rt-hub-internet-egress-${var.default_prefix}-${var.starter_locations[0]}-${local.default_postfix}"
      routing_address_space           = ["0.0.0.0/0"]
      ddos_protection_plan_id         = local.ddos_protection_plan_id == "" ? null : local.ddos_protection_plan_id
      firewall = var.enable_firewall ? {
        sku_name              = "AZFW_VNet"
        sku_tier              = var.use_premium_firewall ? "Premium" : "Standard"
        subnet_address_prefix = var.custom_subnets["AzureFirewallSubnet"].address_prefixes
        firewall_policy_id    = var.az_firewall_policies_enabled == true ? module.firewall_policy.resource.id : null
        default_ip_configuration = {
          tags = var.tags
        }
      } : null
    }
  }

  depends_on = [
    module.hub_rg,
    module.firewall_policy
  ]
}

output "firewall_id" {
  value = var.deploy_hub_network ? module.hubnetworks[0].firewalls["hub"].id : null
}

output "firewall_ip_address" {
  value = var.deploy_hub_network ? module.hubnetworks[0].firewalls["hub"].public_ip_address : null
}

output "virtual_network_id" {
  value = var.deploy_hub_network ? module.hubnetworks[0].virtual_networks["hub"].id : null
}
