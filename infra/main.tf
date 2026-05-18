terraform {

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.61.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
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
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = "rg-unstacked-jobcompanies-dev-ukwest"
}

resource "azuread_group" "sql_server_admins" {
  display_name     = "grp-unstacked-jobcompanies-dev-sql-admin"
  security_enabled = true

  owners  = [data.azurerm_client_config.current.object_id]
  members = [data.azurerm_client_config.current.object_id]
}

resource "azurerm_mssql_server" "sql" {
  name                          = "sql-unstacked-jobcompanies-dev-uksouth"
  resource_group_name           = data.azurerm_resource_group.rg.name
  location                      = "uksouth" # ukwest not supported! 
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true

  azuread_administrator {
    login_username              = azuread_group.sql_server_admins.display_name
    object_id                   = azuread_group.sql_server_admins.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "db" {
  name           = "sqldb-unstacked-jobcompanies-dev"
  server_id      = azurerm_mssql_server.sql.id
  sku_name       = "Basic"
  max_size_gb    = 2
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  zone_redundant = false

  short_term_retention_policy {
    retention_days = 7
  }
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
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

  app_settings = {
    # Deploy step sets these settings:
    "WEBSITE_RUN_FROM_PACKAGE"        = "1"
    "WEBSITE_ENABLE_SYNC_UPDATE_SITE" = "true"
    "SqlConnectionString"             = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.sql_connection_string.versionless_id})"
  }

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

resource "azurerm_key_vault" "keyvault" {
  name                          = "kvunstackedjcdevukwest"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false # We want to recreate in dev
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
}

resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "SqlConnection"
  key_vault_id = azurerm_key_vault.keyvault.id
  value        = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

  depends_on = [azurerm_role_assignment.tf_kv_secrets_officer]
}

resource "azurerm_role_assignment" "tf_kv_secrets_officer" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "web_app_kv_secrets_user" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_web_app.web.identity[0].principal_id
}

output "app_service_name" {
  value = azurerm_windows_web_app.web.name
}