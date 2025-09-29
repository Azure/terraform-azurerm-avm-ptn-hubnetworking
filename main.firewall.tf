module "hub_firewalls" {
  source   = "Azure/avm-res-network-azurefirewall/azurerm"
  version  = "0.4.0"
  for_each = local.firewalls

  firewall_sku_name   = each.value.sku_name
  firewall_sku_tier   = each.value.sku_tier
  location            = var.hub_virtual_networks[each.key].location
  name                = each.value.name
  resource_group_name = local.resource_group_names[each.key]
  enable_telemetry    = var.enable_telemetry
  firewall_management_ip_configuration = each.value.management_ip_enabled ? {
    name                 = try(each.value.management_ip_configuration.name, null)
    public_ip_address_id = try(module.fw_management_ips[each.key].public_ip_id, null)
    subnet_id            = try(module.hub_virtual_network_subnets["${each.key}-${local.firewall_management_subnet_name}"].resource_id, null)
  } : null
  firewall_policy_id         = each.value.firewall_policy_id
  firewall_private_ip_ranges = each.value.private_ip_ranges
  firewall_zones             = each.value.zones
  ip_configurations          = local.firewall_ip_configurations[each.key]
  tags                       = each.value.tags == null ? var.tags : each.value.tags
}

module "fw_default_ips" {
  source   = "Azure/avm-res-network-publicipaddress/azurerm"
  version  = "0.2.0"
  for_each = local.fw_default_ip_configuration_pip

  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  allocation_method   = "Static"
  enable_telemetry    = var.enable_telemetry
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags                = each.value.tags == null ? var.tags : each.value.tags
  zones               = each.value.zones
}

module "fw_management_ips" {
  source   = "Azure/avm-res-network-publicipaddress/azurerm"
  version  = "0.2.0"
  for_each = local.fw_management_ip_configuration_pip

  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  allocation_method   = "Static"
  enable_telemetry    = var.enable_telemetry
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags                = each.value.tags == null ? var.tags : each.value.tags
  zones               = each.value.zones
}

module "fw_policies" {
  source   = "Azure/avm-res-network-firewallpolicy/azurerm"
  version  = "0.3.3"
  for_each = local.fw_policies

  location                                          = var.hub_virtual_networks[each.key].location
  name                                              = each.value.name
  resource_group_name                               = local.resource_group_names[each.key]
  enable_telemetry                                  = var.enable_telemetry
  firewall_policy_auto_learn_private_ranges_enabled = each.value.auto_learn_private_ranges_enabled
  firewall_policy_base_policy_id                    = each.value.base_policy_id
  firewall_policy_dns                               = each.value.dns
  firewall_policy_explicit_proxy                    = each.value.explicit_proxy
  firewall_policy_identity                          = each.value.identity
  firewall_policy_insights                          = each.value.insights
  firewall_policy_intrusion_detection               = each.value.intrusion_detection
  firewall_policy_private_ip_ranges                 = each.value.private_ip_ranges
  firewall_policy_sku                               = each.value.sku
  firewall_policy_sql_redirect_allowed              = each.value.sql_redirect_allowed
  firewall_policy_threat_intelligence_allowlist     = each.value.threat_intelligence_allowlist
  firewall_policy_threat_intelligence_mode          = each.value.threat_intelligence_mode
  firewall_policy_timeouts                          = each.value.timeouts
  firewall_policy_tls_certificate                   = each.value.tls_certificate
  tags                                              = each.value.tags == null ? var.tags : each.value.tags
}
