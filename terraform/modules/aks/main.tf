variable "prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "location" {
  type        = string
  description = "Azure region for resources"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "vnet_subnet_id" {
  type        = string
  description = "ID of the subnet for AKS nodes"
}


variable "acr_id" {
  type        = string
  description = "ID of the Azure Container Registry"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "admin_group_object_ids" {
  type        = list(string)
  description = "List of Azure AD group object IDs for cluster admins"
}

variable "node_vm_size" {
  type        = string
  description = "VM size for AKS nodes"
}

variable "node_min_count" {
  type        = number
  description = "Minimum number of nodes for auto-scaling."
}

variable "node_max_count" {
  type        = number
  description = "Maximum number of nodes for auto-scaling."
}

variable "app_gateway_id" {
  type        = string
  description = "ID of the Application Gateway"
  default     = null
}

variable "user_assigned_identity_id" {
  type        = string
  description = "The resource ID of the user-assigned identity for AKS."
}


resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.prefix}-aks"

  default_node_pool {
    name                = "agentpool"
    vm_size             = var.node_vm_size
    min_count           = var.node_min_count
    max_count           = var.node_max_count
    auto_scaling_enabled = true
    type                = "VirtualMachineScaleSets"
    vnet_subnet_id      = var.vnet_subnet_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.10.0.0/16"
    dns_service_ip = "10.10.0.10"
  }

  ingress_application_gateway {
    gateway_id = var.app_gateway_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Outputs
output "kubelet_identity" {
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  description = "The object ID of the AKS Kubelet managed identity."
}

output "kubelet_identity_client_id" {
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].client_id
  description = "The client ID of the AKS Kubelet managed identity."
}

output "identity_resource_id" {
  value       = var.user_assigned_identity_id
  description = "The resource ID of the AKS Kubelet managed identity."
}

output "cluster_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "Name of the AKS cluster"
}

output "cluster_fqdn" {
  value       = azurerm_kubernetes_cluster.aks.fqdn
  description = "FQDN of the AKS cluster"
}
output "node_resource_group" {
 value = azurerm_kubernetes_cluster.aks.node_resource_group
 description = "The name of the resource group where the AKS nodes are located."
}