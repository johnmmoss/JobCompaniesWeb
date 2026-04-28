terraform {

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.61.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-unstacked-jobcompanies-dev-ukwest"
    storage_account_name = "stjobcompaniesdevukwest"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "rg" {
  name = "rg-unstacked-jobcompanies-dev-ukwest"
}

resource "azurerm_service_plan" "plan" {
  name                = "asp-unstacked-jobcompanies-dev-ukwest"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku_name            = "F1"
  os_type             = "Windows"
}

resource "azurerm_windows_web_app" "web" {
  name                = "app-unstacked-jobcompanies-dev-ukwest"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = azurerm_service_plan.plan.location
  service_plan_id     = azurerm_service_plan.plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v8.0"
    }
  }
}