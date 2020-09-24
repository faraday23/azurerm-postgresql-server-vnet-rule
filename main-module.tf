variable "srvr_id" {
  description = "identifier appended to srvr name for more info see https://github.com/[redacted]/python-azure-naming#azuredbforpostgresql"
  type        = string
}

variable "srvr_id_replica" {
  description = "identifier appended to srvr name for more info see https://github.com/[redacted]/python-azure-naming#azuredbforpostgresql"
  type        = string
}

variable "names" {
  description = "names to be applied to resources"
  type        = map(string)
}

variable "tags" {
  description = "tags to be applied to resources"
  type        = map(string)
}

# Configure Azure Providers
provider "azurerm" {
  version = ">=2.2.0"
  subscription_id = "00000000-0000-0000-0000-0000000"
  features {}
}

##
# Pre-Build Modules 
##

module "subscription" {
  source          = "github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = "00000000-0000-0000-0000-0000000"
}

module "rules" {
  source = "git@github.com:[redacted]/python-azure-naming.git?ref=tf"
}

# For tags and info see https://github.com/Azure-Terraform/terraform-azurerm-metadata 
# For naming convention see https://github.com/openrba/python-azure-naming 
module "metadata" {
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.1.0"

  naming_rules = module.rules.yaml
  
  market              = "us"
  location            = "useast1"
  sre_team            = "alpha"
  environment         = "sandbox"
  project             = "postgresql"
  business_unit       = "iog"
  product_group       = "tfe"
  product_name        = "postgresql"
  subscription_id     = module.subscription.output.subscription_id
  subscription_type   = "nonprod"
  resource_group_type = "app"
}

# postgresql-server storage account
module "storage_acct" {
  source = "../postgresql_module/storage_account"
  # Required inputs 
  # Pre-Built Modules  
  location              = module.metadata.location
  names                 = module.metadata.names
  tags                  = module.metadata.tags
  resource_group_name   = "app-postgresql-sandbox-useast1"
}

# mysql-server module
module "postgresql_server" {
  source = "../postgresql_module/postgresql_vnet_rule"
  # Required inputs 
  srvr_id                   = "01"
  srvr_id_replica           = "02"
  resource_group_name       = "app-postgresql-sandbox-useast1"
  # Replica server required inputs
  enable_replica            = true
  create_mode               = "Replica"
  creation_source_server_id = module.postgresql_server.primary_postgresql_server_id
  # Pre-Built Modules  
  location = module.metadata.location
  names    = module.metadata.names
  tags     = module.metadata.tags
  # postgresql server and database audit policies and advanced threat protection 
  enable_threat_detection_policy = true
  # Storage endpoints for atp logs
  storage_endpoint               = module.storage_acct.primary_blob_endpoint
  storage_account_access_key     = module.storage_acct.primary_access_key  
  # Enable azure ad admin
  enable_postgresql_ad_admin     = true
  ad_admin_login_name            = "first.last@contoso.com"
  ad_admin_login_name_replica    = "first.last@contoso.com"
  # private link endpoint
  enable_private_endpoint        = false
  # Virtual network - for Existing virtual network
  enable_vnet_rule                 = true
  vnet_resource_group_name         = "app-postgresql-sandbox-useast1"      #must be existing resource group within same region as primary server
  vnet_replica_resource_group_name = "app-postgresql-sandbox-westus"       #must be existing resource group within same region as replica server
  virtual_network_name             = "vnet-postgresql-sandbox-eastus-1337" #must be existing vnet with available address space
  virtual_network_name_replica     = "vnet-postgresql-sandbox-westus"      #must be existing vnet with available address space
  allowed_cidrs                    = ["192.168.2.0/24"]   #must be unique available address space within primary server vnet
  allowed_cidrs_replica            = ["172.18.1.0/24"]    #must be unique available address space within replica server vnet
  subnet_name_primary              = "default2" #must be unique subnet name 
  subnet_name_replica              = "default2" #must be unique subnet name 
}
