variable "prefix" {
  type    = string
  default = "abhidemo"
}

variable "location" {
  type    = string
  default = "eastus"
}

# Azure AD / Entra
variable "tenant_id" {
  type    = string
  default = "ae9f4a74-b03c-4e45-915f-d4a43471afac"
}

variable "admin_group_object_ids" {
  type    = list(string)
  default = ["bd8dc798-f360-4c64-98ac-88a23218d8d9"]
}

variable "user_assigned_identity_name" {
  type        = string
  description = "Name of the user-assigned identity for AKS."
  default     = "abhidemo-aks-identity"
}


# variable "dns_zone_rg" {
#   type    = string
#   default = "dns-rg"
# }

# ACR
variable "acr_name" {
  type    = string
  default = "abhacr"
}

# Node sizing / CPU cap: keep node_vcpu * max_nodes <= 4
variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v3" # D2s_v3 = 2 vCPU
}

variable "node_vcpu" {
  type    = number
  default = 2
}

variable "node_min_count" {
  type        = number
  default     = 1
  description = "Minimum number of nodes for the AKS cluster."
}

variable "node_max_count" {
  type        = number
  default     = 2
  description = "Maximum number of nodes for the AKS cluster."
}

