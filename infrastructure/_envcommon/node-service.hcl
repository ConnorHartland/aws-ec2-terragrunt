# Common configuration for all node-service deployments
# This file is included by service-specific terragrunt.hcl files

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/node-service"
}

# Read environment-level configuration
locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

# VPC dependency - provides networking configuration
dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders("env.hcl"))}/vpc"

  # Mock outputs for validate/plan without real VPC
  mock_outputs = {
    vpc_id             = "vpc-mock-12345678"
    private_subnet_ids = ["subnet-private-1", "subnet-private-2", "subnet-private-3"]
    public_subnet_ids  = ["subnet-public-1", "subnet-public-2", "subnet-public-3"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Default inputs for all node services
# These can be overridden in service-specific terragrunt.hcl
inputs = {
  # From VPC dependency
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  public_subnet_ids  = dependency.vpc.outputs.public_subnet_ids

  # From env.hcl
  environment      = local.env_vars.locals.environment
  ami_id           = local.env_vars.locals.ami_id
  artifact_bucket  = local.env_vars.locals.artifact_bucket
  ssl_bucket       = local.env_vars.locals.ssl_bucket
  wazuh_manager_ip = local.env_vars.locals.wazuh_manager_ip

  # Network CIDRs from env.hcl
  mongo_cidrs = try(local.env_vars.locals.mongo_cidrs, [])
  sql_cidrs   = try(local.env_vars.locals.sql_cidrs, [])
  kafka_cidrs = try(local.env_vars.locals.kafka_cidrs, [])

  # Default instance configuration from env.hcl
  instance_type    = try(local.env_vars.locals.default_instance_type, "t3.medium")
  min_size         = try(local.env_vars.locals.default_min_size, 1)
  max_size         = try(local.env_vars.locals.default_max_size, 4)
  desired_capacity = try(local.env_vars.locals.default_desired_capacity, 2)

  # Default autoscaling thresholds from env.hcl
  scale_up_cpu_threshold   = try(local.env_vars.locals.scale_up_cpu_threshold, 70)
  scale_down_cpu_threshold = try(local.env_vars.locals.scale_down_cpu_threshold, 30)

  # Feature flag defaults - most services need these
  needs_alb          = true
  needs_mongo        = false
  needs_sql          = false
  needs_kafka        = true
  needs_https_egress = true
  needs_s3_logs      = true

  # Application defaults
  app_port          = 3000
  health_check_path = "/health"

  # Empty defaults for optional configurations
  additional_iam_policy_arns    = []
  additional_security_group_ids = []
  environment_variables         = {}
  s3_ssl_paths                  = []
  ssm_parameters                = {}
  app_version                   = "latest"
  tags                          = {}
}
