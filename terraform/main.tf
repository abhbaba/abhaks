resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}


# ACR
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = false
}



# Network module
module "network" {
  source         = "./modules/network"
  prefix         = var.prefix
  resource_group = azurerm_resource_group.rg.name
  location       = var.location
}

# Application Gateway
resource "azurerm_public_ip" "app_gateway" {
  name                = "${var.prefix}-appgw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "app_gateway" {
  name                = "${var.prefix}-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = module.network.app_gateway_subnet_id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "appGatewayFrontendIpConfig"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  backend_address_pool {
    name = "default-backend-pool"
  }

  backend_http_settings {
    name                  = "default-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "default-http-listener"
    frontend_ip_configuration_name = "appGatewayFrontendIpConfig"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "default-routing-rule"
    rule_type                  = "Basic"
    priority                   = 20000
    http_listener_name         = "default-http-listener"
    backend_address_pool_name  = "default-backend-pool"
    backend_http_settings_name = "default-http-settings"
  }
}

# AKS module
module "aks" {
  source                    = "./modules/aks"
  prefix                    = var.prefix
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
  vnet_subnet_id            = module.network.aks_subnet_id
  acr_id                    = azurerm_container_registry.acr.id
  tenant_id                 = var.tenant_id
  admin_group_object_ids    = var.admin_group_object_ids
  node_vm_size              = var.node_vm_size
  node_min_count            = var.node_min_count
  node_max_count            = var.node_max_count
  app_gateway_id            = azurerm_application_gateway.app_gateway.id
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_identity.id
}

# User-Assigned Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = var.user_assigned_identity_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Data source to look up the managed identity created by the AGIC add-on
data "azurerm_user_assigned_identity" "agic_identity" {
  name                = "ingressapplicationgateway-${module.aks.cluster_name}"
  resource_group_name = module.aks.node_resource_group
  depends_on = [
    module.aks
  ]
}

# Grant AGIC identity access to the Application Gateway resource group
resource "azurerm_role_assignment" "agic_rg_reader" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = data.azurerm_user_assigned_identity.agic_identity.principal_id
}

# Grant AGIC identity access to the Application Gateway
resource "azurerm_role_assignment" "agic_app_gateway_contributor" {
  scope                = azurerm_application_gateway.app_gateway.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.agic_identity.principal_id
}

# Grant AGIC identity access to the Application Gateway Subnet
resource "azurerm_role_assignment" "agic_subnet_network_contributor" {
  scope                = module.network.app_gateway_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.agic_identity.principal_id
}

# Key Vault for secrets
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {

  name                       = "${var.prefix}-kv"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
  rbac_authorization_enabled = true
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
# Grafana admin password secret
resource "azurerm_key_vault_secret" "grafana_admin_password" {
  name         = "grafana-admin-password"
  value        = random_password.grafana.result
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.kv_admin]
}

resource "random_password" "grafana" {
  length  = 16
  special = true
}

# Grant the AKS Kubelet identity access to Key Vault for the CSI driver
resource "azurerm_role_assignment" "kv_csi_driver_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aks.kubelet_identity
}