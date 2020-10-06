# toggles on/off auditing and advanced threat protection policy for sql server
locals {
    if_threat_detection_policy_enabled = var.enable_threat_detection_policy ? [{}] : []                
}

# Configure the Azure Provider
provider "azurerm" {
  version = ">=2.2.0"
  features {}
}

# creates random password for postgresSQL admin account
resource "random_password" "replica_pw" {
  length      = 24
  special     = true
}

data "azurerm_postgresql_server" "primary" {
  name                = var.primary_server_name
  resource_group_name = "app-postgresql-sandbox-useast1"
}

# Manages a PostgreSQL Server
resource "azurerm_postgresql_server" "replica" {
  count               = var.enable_replica ? 1 : 0
  name                = "${var.names.product_name}-${var.replica_server_location}-${var.names.environment}-${var.srvr_id_replica}"
  location            = var.replica_server_location
  resource_group_name = var.resource_group_name

  administrator_login          = var.administrator_login
  administrator_login_password = random_password.replica_pw.result

  sku_name   = var.sku_name
  version    = var.db_version
  storage_mb = var.storage_mb

  backup_retention_days             = var.backup_retention_days
  geo_redundant_backup_enabled      = var.geo_redundant_backup_enabled
  auto_grow_enabled                 = var.auto_grow_enabled
  public_network_access_enabled     = var.public_network_access_enabled
  infrastructure_encryption_enabled = var.infrastructure_encryption_enabled
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
  create_mode                       = var.create_mode
  creation_source_server_id         = data.azurerm_postgresql_server.primary.id

  dynamic "threat_detection_policy" {
      for_each = local.if_threat_detection_policy_enabled
      content {
          storage_endpoint           = var.storage_endpoint
          storage_account_access_key = var.storage_account_access_key 
          retention_days             = var.log_retention_days
      }
  }
}

# Sets a PostgreSQL Configuration value on a PostgreSQL Server.
resource "azurerm_postgresql_configuration" "config_replica" {
  for_each            = local.postgresql_config

  name                = each.key
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.replica.0.name
  value               = each.value
}

data "azurerm_client_config" "current" {}

resource "azurerm_postgresql_active_directory_administrator" "aduser2" {
  count               = var.enable_replica && var.enable_postgresql_ad_admin ? 1 : 0
  server_name         = azurerm_postgresql_server.replica.0.name
  resource_group_name = var.resource_group_name
  login               = var.ad_admin_login_name_replica
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_postgresql_server.replica]
}

# vnet endpoint for postgresSQL Server - Existing vnet
data "azurerm_virtual_network" "replica_vnet" {
  name                = var.virtual_network_name_replica
  resource_group_name = var.vnet_replica_resource_group_name
}

# Subnet endpoint for postgresSQL Replica Server - Existing subnet
data "azurerm_subnet" "replica_subnet" {
  name                 = var.subnet_name_replica
  resource_group_name  = var.vnet_replica_resource_group_name
  virtual_network_name = data.azurerm_virtual_network.replica_vnet.name
}

# PostgreSQL Virtual Network Rule - Default is "false"
resource "azurerm_postgresql_virtual_network_rule" "vn_rule02" {
  count = var.enable_replica && var.enable_vnet_rule ? 1 : 0 

  name                = "${var.names.product_name}-${var.replica_server_location}-${var.srvr_id_replica}"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.replica.0.name
  subnet_id           = data.azurerm_subnet.replica_subnet.id
}

# PostgreSQL Firewall rule - Default is "false"
resource "azurerm_postgresql_firewall_rule" "fw02" {
  count               = var.enable_replica && var.enable_firewall_rules && length(var.firewall_rules) > 0 ? length(var.firewall_rules) : 0
  name                = element(var.firewall_rules, count.index).name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.replica.0.name
  start_ip_address    = element(var.firewall_rules, count.index).start_ip_address
  end_ip_address      = element(var.firewall_rules, count.index).end_ip_address
}

