locals {
  firewall_policy_id = {
    for vnet_name, policy in module.fw_policies : vnet_name => policy.resource_id
  }
}

locals {
  firewalls = {
    for vnet_name, vnet in var.hub_virtual_networks : vnet_name => {
      name                  = coalesce(vnet.firewall.name, "fw-${vnet_name}")
      sku_name              = vnet.firewall.sku_name
      sku_tier              = vnet.firewall.sku_tier
      subnet_address_prefix = vnet.firewall.subnet_address_prefix
      firewall_policy_id    = try(local.firewall_policy_id[vnet_name], vnet.firewall.firewall_policy_id, null)
      resource_group_name   = try(vnet.resource_group_name, azurerm_resource_group.rg[vnet_name].name)
      private_ip_ranges     = vnet.firewall.private_ip_ranges
      tags                  = vnet.firewall.tags
      default_ip_configuration = {
        name = try(coalesce(vnet.firewall.default_ip_configuration.name, "default"), "default")
      }
      management_ip_enabled = try(vnet.firewall.management_ip_enabled, true)
      management_ip_configuration = try(vnet.firewall.management_ip_enabled, true) ? {} : {
        name = try(coalesce(vnet.firewall.management_ip_configuration.name, "defaultMgmt"), "defaultMgmt")
      }
      zones = vnet.firewall.zones
    } if vnet.firewall != null
  }
  fw_default_ip_configuration_pip = {
    for vnet_name, vnet in var.hub_virtual_networks : vnet_name => {
      location            = vnet.location
      name                = try(coalesce(vnet.firewall.default_ip_configuration.public_ip_config.name, "pip-fw-${vnet_name}"), "pip-fw-${vnet_name}")
      resource_group_name = try(vnet.resource_group_name, azurerm_resource_group.rg[vnet_name].name)
      ip_version          = try(vnet.firewall.default_ip_configuration.public_ip_config.ip_version, "IPv4")
      sku_tier            = try(vnet.firewall.default_ip_configuration.public_ip_config.sku_tier, "Regional")
      tags                = vnet.firewall.tags
      zones               = try(vnet.firewall.default_ip_configuration.public_ip_config.zones, null)
    } if vnet.firewall != null
  }
  fw_management_ip_configuration_pip = {
    for vnet_name, vnet in var.hub_virtual_networks : vnet_name => {
      location            = vnet.location
      name                = try(coalesce(vnet.firewall.management_ip_configuration.public_ip_config.name, "pip-fw-mgmt-${vnet_name}"), "pip-fw-mgmt-${vnet_name}")
      resource_group_name = try(vnet.resource_group_name, azurerm_resource_group.rg[vnet_name].name)
      ip_version          = try(vnet.firewall.management_ip_configuration.public_ip_config.ip_version, "IPv4")
      sku_tier            = try(vnet.firewall.management_ip_configuration.public_ip_config.sku_tier, "Regional")
      tags                = vnet.firewall.tags
      zones               = try(vnet.firewall.management_ip_configuration.public_ip_config.zones, null)
    } if vnet.firewall != null && try(vnet.firewall.management_ip_enabled, true)
  }
  fw_policies = {
    for vnet_name, vnet in var.hub_virtual_networks : vnet_name => {
      name                              = try(vnet.firewall.firewall_policy.name, "fwp-${vnet_name}")
      location                          = vnet.location
      resource_group_name               = try(vnet.resource_group_name, azurerm_resource_group.rg[vnet_name].name)
      sku                               = try(vnet.firewall.firewall_policy.sku, "Standard")
      auto_learn_private_ranges_enabled = try(vnet.firewall.firewall_policy.auto_learn_private_ranges_enabled, null)
      base_policy_id                    = try(vnet.firewall.firewall_policy.base_policy_id, null)
      dns                               = try(vnet.firewall.firewall_policy.dns, null)
      threat_intelligence_allowlist     = try(vnet.firewall.firewall_policy.threat_intelligence_allowlist, null)
      explicit_proxy                    = try(vnet.firewall.firewall_policy.explicit_proxy, null)
      identity                          = try(vnet.firewall.firewall_policy.identity, null)
      insights                          = try(vnet.firewall.firewall_policy.insights, null)
      intrusion_detection               = try(vnet.firewall.firewall_policy.intrusion_detection, null)
      private_ip_ranges                 = try(vnet.firewall.firewall_policy.private_ip_ranges, null)
      sql_redirect_allowed              = try(vnet.firewall.firewall_policy.sql_redirect_allowed, null)
      threat_intelligence_mode          = try(vnet.firewall.firewall_policy.threat_intelligence_mode, null)
      timeouts                          = try(vnet.firewall.firewall_policy.timeouts, null)
      tls_certificate                   = try(vnet.firewall.firewall_policy.tls_certificate, null)
      tags                              = vnet.firewall.tags
    } if vnet.firewall != null && try(vnet.firewall.firewall_policy, null) != null && try(vnet.firewall.firewall_policy_id, null) == null
  }
}
