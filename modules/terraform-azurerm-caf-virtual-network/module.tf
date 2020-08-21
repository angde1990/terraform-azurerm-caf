// Creates the networks virtual network, the subnets and associated NSG, with a special section for AzureFirewallSubnet
resource "azurecaf_naming_convention" "caf_name_vnet" {
  name          = var.networking_object.vnet.name
  prefix        = var.prefix != "" ? var.prefix : null
  postfix       = var.postfix != "" ? var.postfix : null
  max_length    = var.max_length != "" ? var.max_length : null
  resource_type = "azurerm_virtual_network"
  convention    = var.convention
}

resource "azurerm_virtual_network" "vnet" {
  name                = azurecaf_naming_convention.caf_name_vnet.result
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.networking_object.vnet.address_space
  tags                = local.tags

  dns_servers = lookup(var.networking_object.vnet, "dns", null)

  dynamic "ddos_protection_plan" {
    for_each = var.ddos_id != "" ? [1] : []

    content {
      id     = var.ddos_id
      enable = true
    }
  }
}

module "special_subnets" {
  source = "./subnet"

  for_each                                       = lookup(var.networking_object, "specialsubnets", {})
  name                                           = each.value.name
  resource_group_name                            = var.resource_group_name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = lookup(each.value, "cidr", [])
  delegation                                     = lookup(each.value, "delegation", {})
  service_endpoints                              = lookup(each.value, "service_endpoints", [])
  enforce_private_link_endpoint_network_policies = lookup(each.value, "enforce_private_link_endpoint_network_policies", false)
  enforce_private_link_service_network_policies  = lookup(each.value, "enforce_private_link_service_network_policies", false)
}

module "subnets" {
  source = "./subnet"

  for_each                                       = lookup(var.networking_object, "subnets", {})
  name                                           = each.value.name
  resource_group_name                            = var.resource_group_name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = lookup(each.value, "cidr", [])
  delegation                                     = lookup(each.value, "delegation", {})
  service_endpoints                              = lookup(each.value, "service_endpoints", [])
  enforce_private_link_endpoint_network_policies = lookup(each.value, "enforce_private_link_endpoint_network_policies", false)
  enforce_private_link_service_network_policies  = lookup(each.value, "enforce_private_link_service_network_policies", false)
}

module "nsg" {
  source = "./nsg"

  resource_group                    = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.vnet.name
  subnets                           = var.networking_object.subnets
  tags                              = local.tags
  location                          = var.location
  network_security_group_definition = var.network_security_group_definition
  diagnostics                       = var.diagnostics
}

# module "traffic_analytics" {
#   source = "./traffic_analytics"

#   rg                      = var.resource_group_name
#   tags                    = var.tags
#   location                = var.location
#   log_analytics_workspace = var.log_analytics_workspace
#   diagnostics_map         = var.diagnostics_map
#   nw_config               = lookup(var.networking_object, "netwatcher", {})
#   nsg                     = module.nsg.nsg_obj
#   netwatcher              = var.netwatcher
# }

resource "azurerm_subnet_network_security_group_association" "nsg_vnet_association" {
  for_each = module.subnets

  subnet_id                 = each.value.id
  network_security_group_id = module.nsg.nsg_obj[each.key].id
}