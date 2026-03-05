(Guided) Deploy Warehouse Infrastructure
Author: Sammy Ndzelen
Date: 05.03.2026

streampulse-terraform/
├── main.tf              # Provider configuration
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values
├── terraform.tfvars     # Variable values (production)
├── locals.tf            # Local values and computed expressions
├── warehouses.tf        # Warehouse resources
├── databases.tf         # Database and schema resources
├── roles.tf             # Role resources
├── grants.tf            # Grant resources
├── monitors.tf          # Resource monitor resources
└── dev.tfvars           # Variable values (development)


## Part 1: Project Structure
# main.tf — Provider configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.87"
    }
  }

  # Remote state backend (to be configured by user)
  # backend "s3" {
  #   bucket = "streampulse-terraform-state"
  #   key    = "snowflake/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "snowflake" {
  # Authentication can be done via environment variables:
  # SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD
  # or via Snowflake CLI configuration
  
  account  = var.snowflake_account
  username = var.snowflake_user
  password = var.snowflake_password
  role     = "SYSADMIN"  # Use SYSADMIN as the provider role for creating all resources
}


## Part 2: Variables and Locals
# variables.tf

# Snowflake connection details
variable "snowflake_account" {
  description = "Snowflake account identifier (e.g., xyz12345.us-east-1)"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake username for Terraform operations"
  type        = string
  sensitive   = true
}

variable "snowflake_password" {
  description = "Snowflake password for Terraform operations"
  type        = string
  sensitive   = true
}

# Environment
variable "environment" {
  description = "Environment name (prod/staging/dev)"
  type        = string
  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "Environment must be one of: prod, staging, dev"
  }
}

# Warehouse configurations
variable "warehouses" {
  description = "Warehouse configurations"
  type = map(object({
    size           = string
    auto_suspend   = number
    min_clusters   = number
    max_clusters   = number
    scaling_policy = string
  }))
}

# Database names
variable "database_names" {
  description = "List of database names"
  type        = list(string)
}

# Schema names
variable "schema_names" {
  description = "List of schema names to create in each database"
  type        = list(string)
}

# Role names
variable "role_names" {
  description = "List of role names"
  type        = list(string)
}

# Resource monitor quotas
variable "resource_monitors" {
  description = "Resource monitor credit quotas"
  type = map(object({
    credit_quota = number
  }))
}

# Time Travel retention days
variable "time_travel_days" {
  description = "Data retention time in days for Time Travel"
  type        = number
  default     = 1
}



## Task: Write terraform.tfvars (production)
# terraform.tfvars — Production environment values

snowflake_account = "streampulse-prod-account"

environment = "prod"

warehouses = {
  loading = {
    size           = "MEDIUM"
    auto_suspend   = 300   # 5 minutes
    min_clusters   = 1
    max_clusters   = 3
    scaling_policy = "STANDARD"
  }
  transform = {
    size           = "LARGE"
    auto_suspend   = 300
    min_clusters   = 1
    max_clusters   = 5
    scaling_policy = "ECONOMY"
  }
  analytics = {
    size           = "LARGE"
    auto_suspend   = 600   # 10 minutes
    min_clusters   = 1
    max_clusters   = 4
    scaling_policy = "STANDARD"
  }
  reporting = {
    size           = "SMALL"
    auto_suspend   = 900   # 15 minutes
    min_clusters   = 1
    max_clusters   = 2
    scaling_policy = "STANDARD"
  }
  dev = {
    size           = "XSMALL"
    auto_suspend   = 600
    min_clusters   = 1
    max_clusters   = 1
    scaling_policy = "STANDARD"
  }
}

database_names = ["STREAMPULSE_PROD", "STREAMPULSE_STAGING"]
schema_names   = ["RAW", "STAGING", "ANALYTICS", "MARTS"]
role_names     = ["LOADER", "TRANSFORMER", "ANALYST", "REPORTER", "DEVELOPER", "DATA_ADMIN"]

resource_monitors = {
  loading = {
    credit_quota = 500
  }
  analytics = {
    credit_quota = 1000
  }
  dev = {
    credit_quota = 200
  }
}

time_travel_days = 1



## Task: Write dev.tfvars (development)
# dev.tfvars — Development environment values

snowflake_account = "streampulse-dev-account"

environment = "dev"

warehouses = {
  loading = {
    size           = "XSMALL"
    auto_suspend   = 60    # 1 minute
    min_clusters   = 1
    max_clusters   = 1
    scaling_policy = "STANDARD"
  }
  transform = {
    size           = "SMALL"
    auto_suspend   = 60
    min_clusters   = 1
    max_clusters   = 1
    scaling_policy = "STANDARD"
  }
  analytics = {
    size           = "SMALL"
    auto_suspend   = 120   # 2 minutes
    min_clusters   = 1
    max_clusters   = 1
    scaling_policy = "STANDARD"
  }
  reporting = {
    size           = "XSMALL"
    auto_suspend   = 180   # 3 minutes
    min_clusters   = 1
    max_clusters   = 1
    scaling_policy = "STANDARD"
  }
  dev = {
    size           = "XSMALL"
    auto_suspend   = 60
    min_clusters   = 1
    max_clusters   = 1
    scaling_policy = "STANDARD"
  }
}

database_names = ["STREAMPULSE_DEV"]
schema_names   = ["RAW", "STAGING", "ANALYTICS", "MARTS"]
role_names     = ["LOADER", "TRANSFORMER", "ANALYST", "REPORTER", "DEVELOPER", "DATA_ADMIN"]

resource_monitors = {
  loading = {
    credit_quota = 50
  }
  analytics = {
    credit_quota = 100
  }
  dev = {
    credit_quota = 50
  }
}

time_travel_days = 0  # No Time Travel in dev to save Costs


## Task: Write locals.tf
# locals.tf — Computed values

locals {
  # Common tags/labels
  common_tags = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "streampulse"
  }

  # Naming convention: prefix all resources with environment
  name_prefix = upper(var.environment)

  # Role hierarchy definition (parent → child relationships)
  role_hierarchy = {
    "DATA_ADMIN"   = ["SYSADMIN"]  # DATA_ADMIN granted to SYSADMIN
    "TRANSFORMER"  = ["DATA_ADMIN"]
    "LOADER"       = ["TRANSFORMER"]
    "ANALYST"      = ["DATA_ADMIN"]
    "REPORTER"     = ["ANALYST"]
    "DEVELOPER"    = ["DATA_ADMIN"]
  }

  # Flat map of database and schema combinations for schema creation
  database_schemas = {
    for pair in setproduct(var.database_names, var.schema_names) :
    "${pair[0]}_${pair[1]}" => {
      database_name = pair[0]
      schema_name   = pair[1]
    }
  }
}



### Part 3: Core Resources
# warehouses.tf
# warehouses.tf — Snowflake Warehouses

resource "snowflake_warehouse" "this" {
  for_each = var.warehouses

  name              = "${local.name_prefix}_${upper(each.key)}_WH"
  warehouse_size    = each.value.size
  auto_suspend      = each.value.auto_suspend
  auto_resume       = true
  min_cluster_count = each.value.min_clusters
  max_cluster_count = each.value.max_clusters
  scaling_policy    = each.value.scaling_policy

  # Connect resource monitor based on warehouse type
  resource_monitor = each.key == "loading" ? snowflake_resource_monitor.this["loading"].name :
                     each.key == "analytics" ? snowflake_resource_monitor.this["analytics"].name :
                     each.key == "dev" ? snowflake_resource_monitor.this["dev"].name : null

  comment = "Managed by Terraform - ${var.environment} ${each.key} warehouse"

  depends_on = [snowflake_resource_monitor.this]
}


##  Task: Write databases.tf
# databases.tf — Databases and Schemas

# Create databases
resource "snowflake_database" "this" {
  for_each = toset(var.database_names)

  name    = each.value
  comment = "Managed by Terraform - ${local.common_tags["environment"]} database"

  # Time Travel configuration
  data_retention_time_in_days = var.time_travel_days
}

# Create schemas in each database
resource "snowflake_schema" "this" {
  for_each = local.database_schemas

  name     = each.value.schema_name
  database = each.value.database_name
  comment  = "Managed by Terraform - ${each.value.schema_name} schema in ${each.value.database_name}"

  depends_on = [snowflake_database.this]
}


### Challenge: How do you create schemas in multiple databases? Consider using locals to flatten the configuration:
locals {
  # Create a flat map: { "prod_raw" = {db="PROD", schema="RAW"}, ... }
  database_schemas = {
    for pair in setproduct(var.database_names, var.schema_names) :
    "${pair[0]}_${pair[1]}" => {
      database = pair[0]
      schema   = pair[1]
    }
  }
}




### Task: Write roles.tf
# roles.tf — Roles and Role Hierarchy

# Create roles
resource "snowflake_role" "this" {
  for_each = toset(var.role_names)

  name    = "${local.name_prefix}_${upper(each.key)}"
  comment = "Managed by Terraform - ${each.key} role"
}

# Role grants (hierarchy)
# Grant DATA_ADMIN to SYSADMIN
resource "snowflake_role_grants" "data_admin_to_sysadmin" {
  role_name = "${local.name_prefix}_DATA_ADMIN"
  roles     = ["SYSADMIN"]
}

# Grant TRANSFORMER to DATA_ADMIN
resource "snowflake_role_grants" "transformer_to_data_admin" {
  role_name = "${local.name_prefix}_TRANSFORMER"
  roles     = ["${local.name_prefix}_DATA_ADMIN"]
}

# Grant LOADER to TRANSFORMER
resource "snowflake_role_grants" "loader_to_transformer" {
  role_name = "${local.name_prefix}_LOADER"
  roles     = ["${local.name_prefix}_TRANSFORMER"]
}

# Grant ANALYST to DATA_ADMIN
resource "snowflake_role_grants" "analyst_to_data_admin" {
  role_name = "${local.name_prefix}_ANALYST"
  roles     = ["${local.name_prefix}_DATA_ADMIN"]
}

# Grant REPORTER to ANALYST
resource "snowflake_role_grants" "reporter_to_analyst" {
  role_name = "${local.name_prefix}_REPORTER"
  roles     = ["${local.name_prefix}_ANALYST"]
}

# Grant DEVELOPER to DATA_ADMIN
resource "snowflake_role_grants" "developer_to_data_admin" {
  role_name = "${local.name_prefix}_DEVELOPER"
  roles     = ["${local.name_prefix}_DATA_ADMIN"]
}



### Task: Write grants.tf
# grants.tf — Access Grants

# Warehouse grants
# LOADER can use LOADING_WH
resource "snowflake_warehouse_grant" "loader_loading_wh" {
  warehouse_name = snowflake_warehouse.this["loading"].name
  privilege      = "USAGE"
  roles          = ["${local.name_prefix}_LOADER"]
}

# TRANSFORMER can use TRANSFORM_WH
resource "snowflake_warehouse_grant" "transformer_transform_wh" {
  warehouse_name = snowflake_warehouse.this["transform"].name
  privilege      = "USAGE"
  roles          = ["${local.name_prefix}_TRANSFORMER"]
}

# ANALYST can use ANALYTICS_WH
resource "snowflake_warehouse_grant" "analyst_analytics_wh" {
  warehouse_name = snowflake_warehouse.this["analytics"].name
  privilege      = "USAGE"
  roles          = ["${local.name_prefix}_ANALYST"]
}

# REPORTER can use REPORTING_WH
resource "snowflake_warehouse_grant" "reporter_reporting_wh" {
  warehouse_name = snowflake_warehouse.this["reporting"].name
  privilege      = "USAGE"
  roles          = ["${local.name_prefix}_REPORTER"]
}

# DEVELOPER can use DEV_WH
resource "snowflake_warehouse_grant" "developer_dev_wh" {
  warehouse_name = snowflake_warehouse.this["dev"].name
  privilege      = "USAGE"
  roles          = ["${local.name_prefix}_DEVELOPER"]
}

# DATA_ADMIN can use all warehouses
resource "snowflake_warehouse_grant" "data_admin_all" {
  for_each = snowflake_warehouse.this

  warehouse_name = each.value.name
  privilege      = "USAGE"
  roles          = ["${local.name_prefix}_DATA_ADMIN"]
}

# Database and schema grants
# LOADER grants
resource "snowflake_database_grant" "loader_database" {
  for_each = toset(var.database_names)

  database_name = each.value
  privilege     = "USAGE"
  roles         = ["${local.name_prefix}_LOADER"]
}

resource "snowflake_schema_grant" "loader_raw" {
  for_each = {
    for db in var.database_names : db => db
  }

  database_name = each.value
  schema_name   = "RAW"
  privilege     = "CREATE TABLE"
  roles         = ["${local.name_prefix}_LOADER"]
}

# TRANSFORMER grants
resource "snowflake_schema_grant" "transformer_staging" {
  for_each = {
    for db in var.database_names : db => db
  }

  database_name = each.value
  schema_name   = "STAGING"
  privilege     = "USAGE"
  roles         = ["${local.name_prefix}_TRANSFORMER"]
}

resource "snowflake_schema_grant" "transformer_analytics" {
  for_each = {
    for db in var.database_names : db => db
  }

  database_name = each.value
  schema_name   = "ANALYTICS"
  privilege     = "CREATE TABLE"
  roles         = ["${local.name_prefix}_TRANSFORMER"]
}

# ANALYST grants
resource "snowflake_schema_grant" "analyst_analytics" {
  for_each = {
    for db in var.database_names : db => db
  }

  database_name = each.value
  schema_name   = "ANALYTICS"
  privilege     = "SELECT"
  roles         = ["${local.name_prefix}_ANALYST"]
}

resource "snowflake_schema_grant" "analyst_marts" {
  for_each = {
    for db in var.database_names : db => db
  }

  database_name = each.value
  schema_name   = "MARTS"
  privilege     = "SELECT"
  roles         = ["${local.name_prefix}_ANALYST"]
}

# REPORTER grants
resource "snowflake_schema_grant" "reporter_marts" {
  for_each = {
    for db in var.database_names : db => db
  }

  database_name = each.value
  schema_name   = "MARTS"
  privilege     = "SELECT"
  roles         = ["${local.name_prefix}_REPORTER"]
}

# DEVELOPER grants
resource "snowflake_database_grant" "developer_database" {
  for_each = toset(var.database_names)

  database_name = each.value
  privilege     = "USAGE"
  roles         = ["${local.name_prefix}_DEVELOPER"]
}

resource "snowflake_schema_grant" "developer_all_schemas" {
  for_each = local.database_schemas

  database_name = each.value.database_name
  schema_name   = each.value.schema_name
  privilege     = "USAGE"
  roles         = ["${local.name_prefix}_DEVELOPER"]
}

# DATA_ADMIN grants
resource "snowflake_database_grant" "data_admin_database" {
  for_each = toset(var.database_names)

  database_name = each.value
  privilege     = "OWNERSHIP"
  roles         = ["${local.name_prefix}_DATA_ADMIN"]
}

resource "snowflake_schema_grant" "data_admin_all_schemas" {
  for_each = local.database_schemas

  database_name = each.value.database_name
  schema_name   = each.value.schema_name
  privilege     = "OWNERSHIP"
  roles         = ["${local.name_prefix}_DATA_ADMIN"]
}


### Task: Write monitors.tf
# monitors.tf — Resource Monitors
# monitors.tf — Resource Monitors

resource "snowflake_resource_monitor" "this" {
  for_each = var.resource_monitors

  name         = "${local.name_prefix}_${upper(each.key)}_MONITOR"
  credit_quota = each.value.credit_quota
  frequency    = "MONTHLY"

  # Configure notification triggers at 75%, 90%, and 100%
  notify_triggers = [75, 90, 100]

  # Configure suspend triggers
  suspend_triggers = [100]

  # Set notify users (can be expanded)
  notify_users = [var.snowflake_user]
}




## Part 4: Outputs (Estimated: 5 minutes)
# Task: Write outputs.tf
# outputs.tf — Export key values

output "warehouse_names" {
  description = "Map of warehouse names"
  value       = { for k, v in snowflake_warehouse.this : k => v.name }
}

output "database_names" {
  description = "List of database names"
  value       = [for db in snowflake_database.this : db.name]
}

output "schema_names" {
  description = "Map of schema names by database"
  value = {
    for db in var.database_names : db => [
      for schema in snowflake_schema.this : schema.name
      if schema.database == db
    ]
  }
}

output "role_names" {
  description = "Map of role names"
  value       = { for k, v in snowflake_role.this : k => v.name }
}

output "resource_monitor_names" {
  description = "Map of resource monitor names"
  value       = { for k, v in snowflake_resource_monitor.this : k => v.name }
}

output "connection_identifiers" {
  description = "Snowflake connection identifiers"
  value = {
    account     = var.snowflake_account
    environment = var.environment
    databases   = [for db in snowflake_database.this : db.name]
  }
}


## Part 5: Multi-Environment Validation (Estimated: 15 minutes)
# Resource Comparison Table

┌─────────────────────┬───────────────────────────┬───────────────────────────┬────────────────────────────────────┐
│ Resource            │ Production                │ Development               │ Difference                         │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ LOADING_WH size     │ MEDIUM                    │ XSMALL                    │ 2 sizes smaller in dev              │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ TRANSFORM_WH size   │ LARGE                     │ SMALL                     │ 2 sizes smaller in dev              │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ ANALYTICS_WH size   │ LARGE                     │ SMALL                     │ 2 sizes smaller in dev              │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ REPORTING_WH size   │ SMALL                     │ XSMALL                    │ 1 size smaller in dev               │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ DEV_WH size         │ XSMALL                    │ XSMALL                    │ Same                                │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Auto-suspend times  │ 5-15 minutes              │ 1-3 minutes               │ ~70% faster suspend in dev          │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Max clusters        │ 2-5                       │ 1                         │ No multi-cluster in dev             │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Time Travel (days)  │ 1                         │ 0                         │ No Time Travel in dev               │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Loading monitor     │ 500 credits               │ 50 credits                │ 90% reduction in dev                │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Analytics monitor   │ 1000 credits              │ 100 credits               │ 90% reduction in dev                │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Dev monitor credits │ 200 credits               │ 50 credits                │ 75% reduction in dev                │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Databases           │ STREAMPULSE_PROD,         │ STREAMPULSE_DEV           │ Single DB in dev vs multiple in prod│
│                     │ STREAMPULSE_STAGING       │                           │                                    │
└─────────────────────┴───────────────────────────┴───────────────────────────┴────────────────────────────────────┘


### Estimated Monthly Cost Comparison
┌─────────────────────┬───────────────────────────┬───────────────────────────┬────────────────────────────────────┐
│ Cost Component      │ Production (Monthly)      │ Development (Monthly)     │ Savings                            │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Compute Credits     │ 2,500 - 3,500 credits     │ 500 - 700 credits         │ ~80% reduction                      │
│ (Warehouses)        │                           │                           │                                    │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Compute Cost        │ $5,000 - $7,000           │ $1,000 - $1,400           │ ~80% savings ($4,000 - $5,600)      │
│ (@ $2.00/credit)    │                           │                           │                                    │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Storage (TB/month)  │ 2-3 TB                    │ 0.5-1 TB                  │ ~70% reduction                      │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Storage Cost        │ $460 - $690                │ $115 - $230               │ ~75% savings ($345 - $460)          │
│ (@ $23/TB)          │                           │                           │                                    │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Cloud Services      │ 250 - 350 credits         │ 50 - 80 credits           │ ~80% reduction                      │
│ (10% of compute)    │                           │                           │                                    │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ Cloud Services Cost │ $500 - $700                │ $100 - $160               │ ~80% savings ($400 - $540)          │
├─────────────────────┼───────────────────────────┼───────────────────────────┼────────────────────────────────────┤
│ TOTAL ESTIMATED     │ $5,960 - $8,390           │ $1,215 - $1,790           │ ~80% savings                        │
│ MONTHLY COST        │                           │                           │ ($4,745 - $6,600)                   │
└─────────────────────┴───────────────────────────┴───────────────────────────┴────────────────────────────────────┘


## Bonus Challenge
# modules/warehouse/main.tf

variable "warehouse_config" {
  description = "Warehouse configuration"
  type = object({
    name           = string
    size           = string
    auto_suspend   = number
    min_clusters   = number
    max_clusters   = number
    scaling_policy = string
    resource_monitor = string
    environment    = string
  })
}

resource "snowflake_warehouse" "this" {
  name              = var.warehouse_config.name
  warehouse_size    = var.warehouse_config.size
  auto_suspend      = var.warehouse_config.auto_suspend
  auto_resume       = true
  min_cluster_count = var.warehouse_config.min_clusters
  max_cluster_count = var.warehouse_config.max_clusters
  scaling_policy    = var.warehouse_config.scaling_policy
  resource_monitor  = var.warehouse_config.resource_monitor
  
  comment = "Managed by Terraform - ${var.warehouse_config.environment} warehouse"
}

output "warehouse_name" {
  value = snowflake_warehouse.this.name
}


## Remote State Configuration
# backend.tf
terraform {
  backend "s3" {
    bucket         = "streampulse-terraform-state"
    key            = "snowflake/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}


# Create a Data Masking Module
# modules/data_masking/main.tf
# modules/data_masking/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "Snowflake-Labs/snowflake"
    }
  }
}

# Create masking policies for PII data
resource "snowflake_masking_policy" "email_mask" {
  name        = "${var.environment}_EMAIL_MASK"
  database    = var.database_name
  schema      = var.schema_name
  signature {
    column {
      name = "email"
      type = "VARCHAR"
    }
  }
  masking_expression = <<-EOF
    CASE 
      WHEN current_role() IN ('${var.admin_role}', '${var.data_admin_role}') THEN email
      WHEN current_role() IN ('${var.analyst_role}') THEN regexp_replace(email, '^.*@', '*****@')
      ELSE '***MASKED***'
    END
  EOF
  return_data_type = "VARCHAR"
  comment          = "Email masking policy - shows full email only to admins, partially to analysts"
}

resource "snowflake_masking_policy" "phone_mask" {
  name        = "${var.environment}_PHONE_MASK"
  database    = var.database_name
  schema      = var.schema_name
  signature {
    column {
      name = "phone"
      type = "VARCHAR"
    }
  }
  masking_expression = <<-EOF
    CASE 
      WHEN current_role() IN ('${var.admin_role}', '${var.data_admin_role}') THEN phone
      ELSE CONCAT('XXX-XXX-', RIGHT(phone, 4))
    END
  EOF
  return_data_type = "VARCHAR"
  comment          = "Phone masking policy - shows last 4 digits only to non-admins"
}

resource "snowflake_masking_policy" "ssn_mask" {
  name        = "${var.environment}_SSN_MASK"
  database    = var.database_name
  schema      = var.schema_name
  signature {
    column {
      name = "ssn"
      type = "VARCHAR"
    }
  }
  masking_expression = <<-EOF
    CASE 
      WHEN current_role() IN ('${var.admin_role}', '${var.data_admin_role}') THEN ssn
      WHEN current_role() IN ('${var.analyst_role}') THEN CONCAT('XXX-XX-', RIGHT(ssn, 4))
      ELSE '***-**-****'
    END
  EOF
  return_data_type = "VARCHAR"
  comment          = "SSN masking policy - full access only for admins"
}

resource "snowflake_masking_policy" "salary_mask" {
  name        = "${var.environment}_SALARY_MASK"
  database    = var.database_name
  schema      = var.schema_name
  signature {
    column {
      name = "salary"
      type = "NUMBER"
    }
  }
  masking_expression = <<-EOF
    CASE 
      WHEN current_role() IN ('${var.admin_role}', '${var.data_admin_role}') THEN salary
      WHEN current_role() IN ('${var.analyst_role}') THEN ROUND(salary / 10000, 0) * 10000
      ELSE NULL
    END
  EOF
  return_data_type = "NUMBER"
  comment          = "Salary masking - rounded to nearest 10k for analysts"
}

resource "snowflake_masking_policy" "credit_card_mask" {
  name        = "${var.environment}_CREDIT_CARD_MASK"
  database    = var.database_name
  schema      = var.schema_name
  signature {
    column {
      name = "credit_card"
      type = "VARCHAR"
    }
  }
  masking_expression = <<-EOF
    CASE 
      WHEN current_role() IN ('${var.admin_role}', '${var.data_admin_role}') THEN credit_card
      ELSE CONCAT('XXXX-XXXX-XXXX-', RIGHT(credit_card, 4))
    END
  EOF
  return_data_type = "VARCHAR"
  comment          = "Credit card masking - shows last 4 digits only"
}

# Apply masking policies to specific tables
resource "snowflake_table_column_masking_policy_application" "customers_email" {
  for_each = var.customer_tables

  database          = var.database_name
  schema            = var.schema_name
  table             = each.value
  column            = "email"
  masking_policy    = snowflake_masking_policy.email_mask.name
}

resource "snowflake_table_column_masking_policy_application" "customers_phone" {
  for_each = var.customer_tables

  database          = var.database_name
  schema            = var.schema_name
  table             = each.value
  column            = "phone"
  masking_policy    = snowflake_masking_policy.phone_mask.name
}

resource "snowflake_table_column_masking_policy_application" "employees_ssn" {
  for_each = var.employee_tables

  database          = var.database_name
  schema            = var.schema_name
  table             = each.value
  column            = "ssn"
  masking_policy    = snowflake_masking_policy.ssn_mask.name
}

resource "snowflake_table_column_masking_policy_application" "employees_salary" {
  for_each = var.employee_tables

  database          = var.database_name
  schema            = var.schema_name
  table             = each.value
  column            = "salary"
  masking_policy    = snowflake_masking_policy.salary_mask.name
}

# Tag-based masking policy application
resource "snowflake_tag" "pii_tag" {
  name     = "${var.environment}_PII_TAG"
  database = var.database_name
  schema   = var.schema_name
  
  allowed_values = ["EMAIL", "PHONE", "SSN", "CREDIT_CARD", "SALARY"]
  comment        = "Tag for PII data classification"
}

resource "snowflake_tag_association" "pii_tag_association" {
  for_each = var.pii_columns

  object_identifier {
    name     = each.value.table_name
    database = var.database_name
    schema   = var.schema_name
  }
  object_type = "COLUMN"
  tag_id      = snowflake_tag.pii_tag.id
  tag_value   = each.value.pii_type
}


# modules/data_masking/variables.tf
# modules/data_masking/variables.tf

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "database_name" {
  description = "Database name for masking policies"
  type        = string
}

variable "schema_name" {
  description = "Schema name for masking policies"
  type        = string
}

variable "admin_role" {
  description = "Admin role name for full access"
  type        = string
}

variable "data_admin_role" {
  description = "Data admin role name"
  type        = string
}

variable "analyst_role" {
  description = "Analyst role name for partial access"
  type        = string
}

variable "customer_tables" {
  description = "List of customer tables containing PII"
  type        = list(string)
  default     = ["CUSTOMERS", "CONTACTS", "LEADS"]
}

variable "employee_tables" {
  description = "List of employee tables containing PII"
  type        = list(string)
  default     = ["EMPLOYEES", "HR_DATA", "PAYROLL"]
}

variable "pii_columns" {
  description = "Map of PII columns with their types"
  type = list(object({
    table_name = string
    column_name = string
    pii_type    = string
  }))
  default = []
}

# Integrate Data Masking in Main Configuration
# data_masking.tf (new file in root)

# data_masking.tf

module "data_masking_prod" {
  source = "./modules/data_making"
  
  environment      = var.environment
  database_name    = "STREAMPULSE_PROD"
  schema_name      = "ANALYTICS"
  admin_role       = "ACCOUNTADMIN"
  data_admin_role  = "${local.name_prefix}_DATA_ADMIN"
  analyst_role     = "${local.name_prefix}_ANALYST"
  
  customer_tables  = ["CUSTOMERS", "USER_PROFILES", "CONTACT_INFO"]
  employee_tables  = ["EMPLOYEES", "HR_DATA"]
  
  pii_columns = [
    { table_name = "CUSTOMERS", column_name = "email", pii_type = "EMAIL" },
    { table_name = "CUSTOMERS", column_name = "phone", pii_type = "PHONE" },
    { table_name = "CUSTOMERS", column_name = "credit_card", pii_type = "CREDIT_CARD" },
    { table_name = "EMPLOYEES", column_name = "ssn", pii_type = "SSN" },
    { table_name = "EMPLOYEES", column_name = "salary", pii_type = "SALARY" },
  ]
}

module "data_masking_staging" {
  source = "./modules/data_masking"
  
  environment      = var.environment
  database_name    = "STREAMPULSE_STAGING"
  schema_name      = "STAGING"
  admin_role       = "ACCOUNTADMIN"
  data_admin_role  = "${local.name_prefix}_DATA_ADMIN"
  analyst_role     = "${local.name_prefix}_ANALYST"
  
  customer_tables  = ["CUSTOMERS_STAGING", "USER_DATA_STAGING"]
  employee_tables  = ["EMPLOYEES_STAGING"]
}

# For development environment
module "data_masking_dev" {
  count = var.environment == "dev" ? 1 : 0
  
  source = "./modules/data_masking"
  
  environment      = var.environment
  database_name    = "STREAMPULSE_DEV"
  schema_name      = "ANALYTICS"
  admin_role       = "ACCOUNTADMIN"
  data_admin_role  = "${local.name_prefix}_DATA_ADMIN"
  analyst_role     = "${local.name_prefix}_ANALYST"
  
  customer_tables  = ["CUSTOMERS"]
  employee_tables  = ["EMPLOYEES"]
  
  # In dev, use sample/dummy data with simplified masking
  pii_columns = [
    { table_name = "CUSTOMERS", column_name = "email", pii_type = "EMAIL" },
    { table_name = "EMPLOYEES", column_name = "salary", pii_type = "SALARY" },
  ]
}

## Network Policy
Create Network Policy Module
# modules/network_policy/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "Snowflake-Labs/snowflake"
    }
  }
}

# Create network policy
resource "snowflake_network_policy" "this" {
  name              = "${var.environment}_NETWORK_POLICY"
  allowed_ip_list   = var.allowed_ip_list
  blocked_ip_list   = var.blocked_ip_list
  comment           = "Network policy for ${var.environment} environment - managed by Terraform"
}

# Attach network policy to account
resource "snowflake_account" "this" {
  count = var.attach_to_account ? 1 : 0
  
  network_policy = snowflake_network_policy.this.name
}

# Attach network policy to specific users
resource "snowflake_user" "network_policy_attachment" {
  for_each = var.users_to_attach
  
  name = each.key
  network_policy = snowflake_network_policy.this.name
}


# modules/network_policy/variables.tf
# modules/network_policy/variables.tf

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "allowed_ip_list" {
  description = "List of allowed IP addresses and CIDR ranges"
  type        = list(string)
  default     = []
}

variable "blocked_ip_list" {
  description = "List of blocked IP addresses and CIDR ranges"
  type        = list(string)
  default     = []
}

variable "attach_to_account" {
  description = "Whether to attach this policy to the account"
  type        = bool
  default     = true
}

variable "users_to_attach" {
  description = "Map of users to attach this policy to"
  type        = map(string)
  default     = {}
}



# Network Policy Configuration
# network_policy.tf

# Production network policy - strict IP restrictions
resource "snowflake_network_policy" "prod" {
  count = var.environment == "prod" ? 1 : 0
  
  name            = "${local.name_prefix}_NETWORK_POLICY"
  allowed_ip_list = [
    "192.168.1.0/24",    # Corporate office
    "10.0.0.0/8",        # VPN range
    "203.0.113.45/32",   # Jump server
    "198.51.100.0/24",   # Data center
  ]
  blocked_ip_list = [
    "0.0.0.0/0",         # Block all other IPs by default
  ]
  
  comment = "Production network policy - restricted to corporate network and VPN"
}

# Staging network policy - slightly more permissive
resource "snowflake_network_policy" "staging" {
  count = var.environment == "prod" ? 1 : 0  # Only in prod account, but for staging DB
  
  name            = "STAGING_NETWORK_POLICY"
  allowed_ip_list = [
    "192.168.1.0/24",    # Corporate office
    "10.0.0.0/8",        # VPN range
    "203.0.113.45/32",   # Jump server
    "198.51.100.0/24",   # Data center
    "172.16.0.0/12",     # Contractor VPN
  ]
  
  comment = "Staging network policy - includes contractor access"
}

# Development network policy - most permissive
resource "snowflake_network_policy" "dev" {
  count = var.environment == "dev" ? 1 : 0
  
  name            = "${local.name_prefix}_NETWORK_POLICY"
  allowed_ip_list = [
    "0.0.0.0/0",         # Allow all IPs in dev
  ]
  
  comment = "Development network policy - open access for development"
}

# Attach network policy to account
resource "snowflake_account" "network_policy_attachment" {
  count = var.environment == "prod" ? 1 : 0
  
  network_policy = snowflake_network_policy.prod[0].name
}

# Attach network policies to specific users based on role
resource "snowflake_user" "admin_network_policy" {
  for_each = var.environment == "prod" ? {
    for role in var.role_names : role => role
    if contains(["DATA_ADMIN", "DEVELOPER"], role)
  } : {}

  name = snowflake_role.this[each.key].name
  
  # Admins and developers use production policy
  network_policy = snowflake_network_policy.prod[0].name
}



# Enhanced Network Policy with IP Allowlisting from Variables
# network_policy_enhanced.tf

# Define IP allowlists as local values
locals {
  ip_allowlists = {
    prod = {
      corporate = ["192.168.1.0/24", "10.10.0.0/16"]
      vpn       = ["10.0.0.0/8", "172.16.0.0/12"]
      datacenter = ["198.51.100.0/24"]
      jump_hosts = ["203.0.113.45/32", "203.0.113.46/32"]
      bi_tools   = ["192.168.2.0/24"]  # IP range for BI tools
    }
    staging = {
      corporate = ["192.168.1.0/24", "10.10.0.0/16"]
      vpn       = ["10.0.0.0/8", "172.16.0.0/12"]
      contractors = ["172.16.1.0/24"]
    }
    dev = {
      any = ["0.0.0.0/0"]
    }
  }
}

# Create network policies with variable-based configuration
resource "snowflake_network_policy" "environment_specific" {
  for_each = {
    for env in ["prod", "staging", "dev"] : env => env
    if var.environment == "prod" || (var.environment == "dev" && env == "dev")
  }

  name = "${upper(each.key)}_NETWORK_POLICY"
  
  allowed_ip_list = flatten([
    for category, ips in local.ip_allowlists[each.key] : ips
  ])
  
  blocked_ip_list = each.key == "dev" ? [] : ["0.0.0.0/0"]
  
  comment = "Network policy for ${each.key} environment - allows ${join(", ", keys(local.ip_allowlists[each.key]))}"
}

# Create a network policy for a specific application
resource "snowflake_network_policy" "app_integration" {
  count = var.environment == "prod" ? 1 : 0
  
  name = "APP_INTEGRATION_POLICY"
  allowed_ip_list = [
    "54.123.45.67/32",   # External application server
    "54.123.45.68/32",   # Backup application server
  ]
  
  comment = "Network policy for external application integration"
}

# Attach application policy to service users
resource "snowflake_user" "service_accounts" {
  for_each = var.environment == "prod" ? {
    "SERVICE_LOADER" = "LOADER"
    "SERVICE_TRANSFORM" = "TRANSFORMER"
  } : {}

  name = each.key
  default_role = "${local.name_prefix}_${each.value}"
  must_change_password = false
  
  # Service accounts use the application integration policy
  network_policy = snowflake_network_policy.app_integration[0].name
}

## Network Policy Variables Extension
# Add to existing variables.tf

variable "network_policies" {
  description = "Network policy configurations by environment"
  type = map(object({
    allowed_ip_list = list(string)
    blocked_ip_list = optional(list(string), ["0.0.0.0/0"])
    description     = optional(string)
  }))
  default = {
    prod = {
      allowed_ip_list = ["192.168.1.0/24", "10.0.0.0/8", "203.0.113.45/32"]
      description     = "Production network restrictions"
    }
    staging = {
      allowed_ip_list = ["192.168.1.0/24", "10.0.0.0/8", "172.16.0.0/12"]
      description     = "Staging with contractor access"
    }
    dev = {
      allowed_ip_list = ["0.0.0.0/0"]
      blocked_ip_list = []
      description     = "Development - open access"
    }
  }
}

variable "service_accounts" {
  description = "Service accounts and their associated roles"
  type = map(object({
    role          = string
    network_policy = optional(string)
  }))
  default = {}
}



## Enhanced locals.tf for Network Policies
# Add to existing locals.tf

locals {
  # Network policy configurations
  network_policy_configs = {
    for env, config in var.network_policies : env => {
      name             = "${upper(env)}_NETWORK_POLICY"
      allowed_ip_list  = config.allowed_ip_list
      blocked_ip_list  = try(config.blocked_ip_list, ["0.0.0.0/0"])
      comment          = try(config.description, "Network policy for ${env}")
    }
  }
  
  # Service account mapping
  service_account_roles = {
    for sa, config in var.service_accounts : sa => {
      role_name      = "${local.name_prefix}_${config.role}"
      network_policy = try(config.network_policy, null)
    }
  }
}

## Dynamic Network Policy Assignment Based on User Roles
  # network_policy_dynamic.tf

# Create a resource to map roles to network policies
resource "snowflake_tag" "network_policy_tag" {
  name     = "${local.name_prefix}_NETWORK_POLICY_TAG"
  database = var.database_names[0]
  schema   = var.schema_names[0]
  
  allowed_values = ["PROD_POLICY", "STAGING_POLICY", "DEV_POLICY", "APP_POLICY"]
  comment        = "Tag to associate users with network policies"
}

# Tag users based on their role for network policy assignment
resource "snowflake_tag_association" "user_network_policy" {
  for_each = snowflake_role.this
  
  object_identifier {
    name     = each.value.name
  }
  object_type = "ROLE"
  tag_id      = snowflake_tag.network_policy_tag.id
  tag_value   = each.key == "DATA_ADMIN" || each.key == "DEVELOPER" ? "PROD_POLICY" :
                each.key == "ANALYST" || each.key == "REPORTER" ? "STAGING_POLICY" : "APP_POLICY"
}

# Create a stored procedure to apply network policies based on tags
resource "snowflake_procedure" "apply_network_policies" {
  name     = "APPLY_NETWORK_POLICIES"
  database = var.database_names[0]
  schema   = var.schema_names[0]
  language = "SQL"
  return_type = "VARCHAR"
  
  statement = <<-SQL
    DECLARE
      user_name STRING;
      policy_name STRING;
      cur CURSOR FOR 
        SELECT 
          u.name as user_name,
          t.tag_value as policy_name
        FROM snowflake.account_usage.users u
        JOIN snowflake.account_usage.tag_references tr 
          ON u.name = tr.object_name
        JOIN snowflake.account_usage.tags t 
          ON tr.tag_id = t.tag_id
        WHERE tr.tag_name = '${local.name_prefix}_NETWORK_POLICY_TAG'
          AND tr.object_type = 'ROLE'
          AND u.name IN (SELECT DISTINCT name FROM snowflake.account_usage.users WHERE deleted IS NULL);
    BEGIN
      FOR record IN cur DO
        EXECUTE IMMEDIATE 'ALTER USER ' || record.user_name || ' SET NETWORK_POLICY = ' || record.policy_name;
      END FOR;
      RETURN 'Network policies applied successfully';
    END;
  SQL
}


# Import Commands for Existing Resources
# Import existing databases
terraform import snowflake_database.this["STREAMPULSE_PROD"] "STREAMPULSE_PROD"
terraform import snowflake_database.this["STREAMPULSE_STAGING"] "STREAMPULSE_STAGING"

# Import existing warehouses
terraform import snowflake_warehouse.this["loading"] "PROD_LOADING_WH"
terraform import snowflake_warehouse.this["transform"] "PROD_TRANSFORM_WH"
terraform import snowflake_warehouse.this["analytics"] "PROD_ANALYTICS_WH"

# Import existing roles
terraform import snowflake_role.this["LOADER"] "PROD_LOADER"
terraform import snowflake_role.this["TRANSFORMER"] "PROD_TRANSFORMER"


