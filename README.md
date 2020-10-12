# azurerm-postgresql-server-vnet-rule
this will deploy postgresql server and database with public access enabled and vnet rule (not using private link endpoint)


```hcl
# required server inputs
variable "srvr_id" {
  description = "identifier appended to srvr name for more info see https://github.com/[redacted]/python-azure-naming#azuredbforpostgresql"
  type        = string
}

variable "srvr_id_replica" {
  description = "identifier appended to srvr name for more info see https://github.com/[redacted]/python-azure-naming#azuredbforpostgresql"
  type        = string
}

# required inputs for tags
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
  subscription_id = "00000000-0000-0000-0000-00000000"
  features {}
}

##
# Pre-Build Modules 
##

module "subscription" {
  source          = "github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = "00000000-0000-0000-0000-00000000"
}

module "rules" {
  source = "git@github.com:[redacted]/python-azure-naming.git?ref=tf"
}

# For tags and info see https://github.com/Azure-Terraform/terraform-azurerm-metadata 
# For naming convention see https://github.com/[redacted]/python-azure-naming 
module "metadata" {
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.1.0"

  naming_rules = module.rules.yaml
  
  market              = "us"
  location            = "uscent1"     # for location list see - https://github.com/[redacted]/python-azure-naming#rbaazureregion
  sre_team            = "alpha"
  environment         = "sandbox"     # for environment list see - https://github.com/[redacted]/python-azure-naming#rbaenvironment
  project             = "postgresql"
  business_unit       = "iog"
  product_group       = "tfe"
  product_name        = "postgresql"  # for product name list see - https://github.com/[redacted]/python-azure-naming#rbaproductname
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

# postgresql-server module
module "postgresql_server" {
  source = "../postgresql_module/postgresql_replica"
  # Pre-Built Modules  
  location = module.metadata.location
  names    = module.metadata.names
  tags     = module.metadata.tags
  # Required inputs 
  srvr_id                   = "01"
  srvr_id_replica           = "03"
  resource_group_name       = "app-postgresql-sandbox-useast1"
  # Enable creation of Database 
  enable_db                 = false
  # Replica server required inputs
  enable_replica            = true
  create_mode               = "Replica"
  primary_server_name       = "postgresql-useast1-sandbox01"
  replica_server_location   = "centralus"
  # Postgresql server and database audit policies and advanced threat protection 
  enable_threat_detection_policy = false
  # Storage endpoints for atp logs
  storage_endpoint               = module.storage_acct.primary_blob_endpoint
  storage_account_access_key     = module.storage_acct.primary_access_key  
  # Enable azure ad admin
  enable_postgresql_ad_admin     = false
  ad_admin_login_name            = "first.last@risk.regn.net"
  ad_admin_login_name_replica    = "first.last@risk.regn.net"
  # private link endpoint
  enable_private_endpoint        = false 
  public_network_access_enabled  = false      # public access will need to be enabled to use vnet rules
  # vnet rules
  enable_vnet_rule               = false
  # Virtual network - for Existing virtual network
  vnet_resource_group_name         = "app-postgresql-sandbox-useast1"      #must be existing resource group within same region as primary server
  vnet_replica_resource_group_name = "app-postgresql-sandbox-westus"       #must be existing resource group within same region as replica server
  virtual_network_name             = "vnet-postgresql-sandbox-eastus-1337" #must be existing vnet with available address space
  virtual_network_name_replica     = "vnet-postgresql-sandbox-westus"      #must be existing vnet with available address space
  subnet_name_primary              = "default" #must be existing subnet name 
  subnet_name_replica              = "default" #must be existing subnet name 
  # Firewall Rules to allow client IP
  enable_firewall_rules            = false
  firewall_rules = [
                {name             = "desktop-ip"
                start_ip_address  = "209.243.0.0"
                end_ip_address    = "209.243.0.0"}]
}
```
