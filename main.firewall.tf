module "hub_firewalls" {
  for_each = local.firewalls
  source   = "Azure/avm-res-network-azurefirewall/azurerm"
  version  = "0.3.0"

  firewall_sku_name   = each.value.sku_name
  firewall_sku_tier   = each.value.sku_tier
  location            = var.hub_virtual_networks[each.key].location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  firewall_ip_configuration = [{
    name                 = each.value.default_ip_configuration.name
    public_ip_address_id = module.fw_default_ips[each.key].public_ip_id
    subnet_id            = module.hub_virtual_network_subnets["${each.key}-${local.firewall_subnet_name}"].resource_id
  }]
  firewall_management_ip_configuration = each.value.sku_tier != "Basic" ? null : {
    name                 = each.value.management_ip_configuration.name
    public_ip_address_id = module.fw_management_ips[each.key].public_ip_id
    subnet_id            = try(module.hub_virtual_network_subnets["${each.key}-${local.firewall_management_subnet_name}"].resource_id, null)
  }
  firewall_policy_id         = each.value.firewall_policy_id
  firewall_private_ip_ranges = each.value.private_ip_ranges
  firewall_zones             = each.value.zones
  tags                       = each.value.tags
  enable_telemetry           = var.enable_telemetry
}

module "fw_default_ips" {
  for_each = local.fw_default_ip_configuration_pip
  source   = "Azure/avm-res-network-publicipaddress/azurerm"
  version  = "0.2.0"

  allocation_method   = "Static"
  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags                = each.value.tags
  zones               = each.value.zones

  enable_telemetry = var.enable_telemetry
}

module "fw_management_ips" {
  for_each = local.fw_management_ip_configuration_pip
  source   = "Azure/avm-res-network-publicipaddress/azurerm"
  version  = "0.2.0"

  allocation_method   = "Static"
  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags                = each.value.tags
  zones               = each.value.zones

  enable_telemetry = var.enable_telemetry
}

module "fw_policies" {
  for_each = { for vnet_name, fw in local.fw_policies : vnet_name => fw if fw.firewall_policy_id == null }
  source   = "Azure/avm-res-network-firewallpolicy/azurerm"
  version  = "0.3.2"

  name                                              = each.value.name
  location                                          = var.hub_virtual_networks[each.key].location
  resource_group_name                               = var.hub_virtual_networks[each.key].resource_group_name
  firewall_policy_sku                               = each.value.sku
  firewall_policy_auto_learn_private_ranges_enabled = each.value.auto_learn_private_ranges_enabled
  firewall_policy_base_policy_id                    = each.value.base_policy_id
  firewall_policy_dns                               = each.value.dns
  firewall_policy_threat_intelligence_mode          = each.value.threat_intelligence_mode
  firewall_policy_private_ip_ranges                 = each.value.private_ip_ranges
  firewall_policy_threat_intelligence_allowlist     = each.value.threat_intelligence_allowlist
  tags                                              = each.value.tags

  enable_telemetry = var.enable_telemetry
}
