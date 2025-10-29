output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "app_gateway_ip" {
  value       = azurerm_public_ip.app_gateway.ip_address
  description = "The public IP address of the Application Gateway."
}

output "kubelet_identity_client_id" {
  value       = module.aks.kubelet_identity_client_id
  description = "The client ID of the AKS Kubelet managed identity."
}


output "application_gateway_name" {
  value       = azurerm_application_gateway.app_gateway.name
  description = "The name of the Application Gateway."
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the resource group."
}

output "identity_resource_id" {
  value       = module.aks.identity_resource_id
  description = "The resource ID of the AKS cluster's managed identity."
}
