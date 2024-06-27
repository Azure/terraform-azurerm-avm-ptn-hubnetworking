# These locals defined here to avoid conflict with test framework
locals {
  firewall_private_ip = {
    for vnet_name, fw in module.hub_firewalls : vnet_name => fw.resource.ip_configuration[0].private_ip_address
  }
  hub_routing = azurerm_route_table.hub_routing
  virtual_networks_modules = {
    for vnet_key, vnet_module in module.hub_virtual_networks : vnet_key => vnet_module
  }
}

# Create rgs as defined by var.hub_networks
resource "azurerm_resource_group" "rg" {
  for_each = { for rg in local.resource_group_data : rg.name => rg }

  location = each.value.location
  name     = each.key
  tags = merge(each.value.tags, (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "2c089a3ac8972bdb97f6de5665678299705fa853"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2023-02-08 02:04:55"
    avm_git_org              = "Azure"
    avm_git_repo             = "terraform-azurerm-avm-ptn-hubnetworking"
    avm_yor_name             = "rg"
    avm_yor_trace            = "f48a6bb9-e2a2-47dc-8663-511a0ff70c96"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/))
}

resource "azurerm_management_lock" "rg_lock" {
  for_each = { for r in local.resource_group_data : r.name => r if r.lock }

  lock_level = "CanNotDelete"
  name       = coalesce(each.value.lock_name, substr("lock-${each.key}", 0, 90))
  scope      = azurerm_resource_group.rg[each.key].id
}

# Module to create virtual networks and subnets
# Useful outputs:
# - vnet_id - the resource id of vnet
# - vnet_subnets_name_ids - a map of subnet name to subnet resource id, e.g. use lookup(module.hub_virtual_networks["key"].vnet_subnets_name_id, "subnet1")
module "hub_virtual_networks" {
  for_each = var.hub_virtual_networks
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.2.3"

  name                = each.value.name
  address_space       = each.value.address_space
  resource_group_name = try(azurerm_resource_group.rg[each.value.resource_group_name].name, each.value.resource_group_name)
  location            = each.value.location

  ddos_protection_plan = each.value.ddos_protection_plan_id == null ? null : {
    id     = each.value.ddos_protection_plan_id
    enable = true
  }
  dns_servers = each.value.dns_servers == null ? null : {
    dns_servers = each.value.dns_servers
  }

  #  peerings = local.hub_peering_map[each.key]
  subnets = try(local.subnets_map[each.key], {})
}

resource "azurerm_route_table" "hub_routing" {
  for_each = local.route_map

  location                      = var.hub_virtual_networks[each.key].location
  name                          = coalesce(var.hub_virtual_networks[each.key].route_table_name, "route-${each.key}")
  resource_group_name           = try(azurerm_resource_group.rg[var.hub_virtual_networks[each.key].resource_group_name].name, var.hub_virtual_networks[each.key].resource_group_name)
  disable_bgp_route_propagation = false
  tags = (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "f0e06dd2b71ff7fc285efa135471f3e2bcef7e7a"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2023-07-04 10:14:08"
    avm_git_org              = "Azure"
    avm_git_repo             = "terraform-azurerm-avm-ptn-hubnetworking"
    avm_yor_name             = "hub_routing"
    avm_yor_trace            = "e942eb18-f7cd-481e-a3ba-0c7815c05857"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/)

  route {
    address_prefix = "0.0.0.0/0"
    name           = "internet"
    next_hop_type  = "Internet"
  }
  dynamic "route" {
    for_each = toset(each.value.mesh_routes)

    content {
      address_prefix         = route.value.address_prefix
      name                   = route.value.name
      next_hop_in_ip_address = route.value.next_hop_ip_address
      next_hop_type          = route.value.next_hop_type
    }
  }
  dynamic "route" {
    for_each = toset(each.value.user_routes)

    content {
      address_prefix         = route.value.address_prefix
      name                   = route.value.name
      next_hop_in_ip_address = route.value.next_hop_ip_address
      next_hop_type          = route.value.next_hop_type
    }
  }
}

resource "azurerm_subnet_route_table_association" "hub_routing_creat" {
  for_each = local.subnet_route_table_association_map

  route_table_id = each.value.route_table_id
  subnet_id      = each.value.subnet_id
}

resource "azurerm_subnet_route_table_association" "hub_routing_external" {
  for_each = local.subnet_external_route_table_association_map

  route_table_id = each.value.route_table_id
  subnet_id      = each.value.subnet_id
}

module "hub_firewalls" {
  for_each = local.firewalls
  source   = "Azure/avm-res-network-azurefirewall/azurerm"
  version  = "0.2.0"

  firewall_sku_name                    = each.value.sku_name
  firewall_sku_tier                    = each.value.sku_tier
  location                             = var.hub_virtual_networks[each.key].location
  name                                 = each.value.name
  resource_group_name                  = var.hub_virtual_networks[each.key].resource_group_name
  firewall_ip_configuration            = [{
    name                 = each.value.default_ip_configuration.name
    public_ip_address_id = azurerm_public_ip.fw_default_ip_configuration_pip[each.key].id
    subnet_id            = azurerm_subnet.fw_subnet[each.key].id
  }]
#  firewall_management_ip_configuration = {
#    name                 = each.value.management_ip_configuration.name
#    public_ip_address_id = azurerm_public_ip.fw_management_ip_configuration_pip[each.key].id
#    subnet_id            = azurerm_subnet.fw_management_subnet[each.key].id
#  }
  firewall_policy_id                   = each.value.firewall_policy_id
  firewall_private_ip_ranges           = each.value.private_ip_ranges
  firewall_zones                       = each.value.zones
  tags                                 = each.value.tags
}

resource "azurerm_public_ip" "fw_default_ip_configuration_pip" {
  for_each = local.fw_default_ip_configuration_pip

  allocation_method   = "Static"
  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags = (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "9d2530df182c2a04d3e065d6312cf623482769da"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2023-03-07 01:43:45"
    avm_git_org              = "Azure"
    avm_git_repo             = "terraform-azurerm-avm-ptn-hubnetworking"
    avm_yor_name             = "fw_default_ip_configuration_pip"
    avm_yor_trace            = "ae85c6f7-49d4-439c-9fcc-028654adce39"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/)
  zones = each.value.zones
}

resource "azurerm_public_ip" "fw_management_ip_configuration_pip" {
  for_each = local.fw_management_ip_configuration_pip

  allocation_method   = "Static"
  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  ip_version          = each.value.ip_version
  sku                 = "Standard"
  sku_tier            = each.value.sku_tier
  tags = (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "a5adfe3141080bef44f5b5d71806635ef562f63b"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2023-08-08 19:29:32"
    avm_git_org              = "Azure"
    avm_git_repo             = "terraform-azurerm-avm-ptn-hubnetworking"
    avm_yor_name             = "fw_management_ip_configuration_pip"
    avm_yor_trace            = "cba83cdf-25a4-43ed-9b79-69c8da133abc"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/)
  zones = each.value.zones
}

resource "azurerm_subnet" "fw_subnet" {
  for_each = local.firewalls

  address_prefixes     = [each.value.subnet_address_prefix]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.hub_virtual_networks[each.key].resource_group_name
  virtual_network_name = module.hub_virtual_networks[each.key].name
}

resource "azurerm_subnet" "fw_management_subnet" {
  for_each = local.firewall_management_subnets

  address_prefixes     = each.value.address_prefixes
  name                 = each.value.name
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = each.value.virtual_network_name

  depends_on = [
    module.hub_virtual_networks
  ]
}

resource "azurerm_subnet_route_table_association" "fw_subnet_routing_creat" {
  for_each = { for vnet_name, fw in local.firewalls : vnet_name => fw if fw.subnet_route_table_id == null }

  route_table_id = azurerm_route_table.hub_routing[each.key].id
  subnet_id      = azurerm_subnet.fw_subnet[each.key].id
}

resource "azurerm_subnet_route_table_association" "fw_subnet_routing_external" {
  for_each = { for vnet_name, fw in local.firewalls : vnet_name => fw if fw.subnet_route_table_id != null }

  route_table_id = each.value.subnet_route_table_id
  subnet_id      = azurerm_subnet.fw_subnet[each.key].id
}

#resource "azurerm_firewall" "fw" {
#  for_each = local.firewalls
#
#  location            = var.hub_virtual_networks[each.key].location
#  name                = each.value.name
#  resource_group_name = var.hub_virtual_networks[each.key].resource_group_name
#  sku_name            = each.value.sku_name
#  sku_tier            = each.value.sku_tier
#  dns_servers         = each.value.dns_servers
#  firewall_policy_id  = each.value.firewall_policy_id
#  private_ip_ranges   = each.value.private_ip_ranges
#  tags = merge(each.value.tags, (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
#    avm_yor_name  = "fw"
#    avm_yor_trace = "26da0e94-b18c-4bd6-9f3d-69264ded141c"
#    } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/), (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
#    avm_git_commit           = "7642c66da269658aac815353f23f030696684632"
#    avm_git_file             = "main.tf"
#    avm_git_last_modified_at = "2023-02-24 10:28:10"
#    avm_git_org              = "Azure"
#    avm_git_repo             = "terraform-azurerm-avm-ptn-hubnetworking"
#  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/))
#  threat_intel_mode = each.value.threat_intel_mode
#  zones             = each.value.zones
#
#  ip_configuration {
#    name                 = each.value.default_ip_configuration.name
#    public_ip_address_id = azurerm_public_ip.fw_default_ip_configuration_pip[each.key].id
#    subnet_id            = azurerm_subnet.fw_subnet[each.key].id
#  }
#  dynamic "management_ip_configuration" {
#    for_each = each.value.sku_tier == "Basic" ? ["managementIpConfiguration"] : []
#
#    content {
#      name                 = each.value.management_ip_configuration.name
#      public_ip_address_id = azurerm_public_ip.fw_management_ip_configuration_pip[each.key].id
#      subnet_id            = azurerm_subnet.fw_management_subnet[each.key].id
#    }
#  }
#}
