terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateacctdummy123"
    container_name       = "tfstate"
    key                  = "prod-aks.terraform.tfstate"
  }
}
