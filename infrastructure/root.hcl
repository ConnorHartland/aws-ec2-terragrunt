# Root Terragrunt configuration for all environments
# This file configures the S3 backend, provider, and common settings

locals {
  # Parse the file path to extract account and environment information
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id   = local.account_vars.locals.account_id
  account_name = local.account_vars.locals.account_name
  aws_profile  = local.account_vars.locals.aws_profile
  aws_region   = local.env_vars.locals.aws_region
  environment  = local.env_vars.locals.environment

  # Generate a unique state key based on the relative path from the accounts directory
  relative_path = path_relative_to_include()
  state_key     = "${local.relative_path}/terraform.tfstate"
}

# Configure S3 backend for remote state storage
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-${local.account_id}-${local.aws_region}"
    key            = local.state_key
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    profile        = local.aws_profile
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate AWS provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROVIDER
provider "aws" {
  region  = "${local.aws_region}"
  profile = "${local.aws_profile}"

  default_tags {
    tags = {
      ManagedBy   = "Terragrunt"
      Environment = "${local.environment}"
      Account     = "${local.account_name}"
      Project     = "node-services"
    }
  }
}
PROVIDER
}

# Configure Terraform version constraints
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }
}

# Inputs available to all child configurations
inputs = {
  aws_region   = local.aws_region
  account_id   = local.account_id
  account_name = local.account_name
  environment  = local.environment
}
