# Root configuration for all Terragrunt modules
# This file is included by all terragrunt.hcl files

locals {
  # Parse account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id   = local.account_vars.locals.account_id
  aws_profile  = local.account_vars.locals.aws_profile
  account_name = local.account_vars.locals.account_name

  aws_region  = local.env_vars.locals.aws_region
  environment = local.env_vars.locals.environment

  # Generate a unique state key based on the relative path
  state_key = "${path_relative_to_include()}/terraform.tfstate"
}

# Configure S3 backend for remote state
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "${local.account_name}-terraform-state-${local.account_id}"
    key            = local.state_key
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"

    s3_bucket_tags = {
      Name        = "Terraform State"
      Environment = local.environment
      ManagedBy   = "Terragrunt"
    }

    dynamodb_table_tags = {
      Name        = "Terraform State Lock"
      Environment = local.environment
      ManagedBy   = "Terragrunt"
    }
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = "${local.aws_region}"
  profile = "${local.aws_profile}"

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "${local.environment}"
      Account     = "${local.account_name}"
      Project     = "node-services"
    }
  }
}
EOF
}

# Configure Terraform version constraints
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
EOF
}

# Default inputs applied to all modules
inputs = {
  environment  = local.environment
  account_id   = local.account_id
  account_name = local.account_name
  aws_region   = local.aws_region
}
