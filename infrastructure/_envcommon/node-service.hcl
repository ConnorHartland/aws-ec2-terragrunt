# -----------------------------------------------------------------------------
# Common Configuration for Node Service Module
# This file is included by all service terragrunt.hcl files
# -----------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/node-service"
}

# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------

dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders("env.hcl"))}/vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock-12345678"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "alb" {
  config_path = "${dirname(find_in_parent_folders("env.hcl"))}/alb"

  mock_outputs = {
    alb_arn               = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/mock-alb/1234567890123456"
    alb_listener_arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock-alb/1234567890123456/1234567890123456"
    alb_security_group_id = "sg-mock-alb-12345678"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  environment     = local.env_vars.locals.environment
  aws_region      = local.env_vars.locals.aws_region
  ami_id          = local.env_vars.locals.ami_id
  artifact_bucket = local.env_vars.locals.artifact_bucket

  # Network CIDRs
  mongo_cidrs = try(local.env_vars.locals.mongo_cidrs, [])
  sql_cidrs   = try(local.env_vars.locals.sql_cidrs, [])
  kafka_cidrs = try(local.env_vars.locals.kafka_cidrs, [])
  redis_cidrs = try(local.env_vars.locals.redis_cidrs, [])

  # Default scaling configuration
  default_min_size         = try(local.env_vars.locals.default_min_size, 1)
  default_max_size         = try(local.env_vars.locals.default_max_size, 4)
  default_desired_capacity = try(local.env_vars.locals.default_desired_capacity, 2)
  default_instance_type    = try(local.env_vars.locals.default_instance_type, "t3.medium")

  # Autoscaling thresholds
  scale_up_cpu_threshold   = try(local.env_vars.locals.scale_up_cpu_threshold, 70)
  scale_down_cpu_threshold = try(local.env_vars.locals.scale_down_cpu_threshold, 30)

  # Optional resources
  s3_logs_bucket = try(local.env_vars.locals.s3_logs_bucket, "")
}

# -----------------------------------------------------------------------------
# Inputs
# -----------------------------------------------------------------------------

inputs = {
  # From dependencies
  vpc_id                = dependency.vpc.outputs.vpc_id
  private_subnet_ids    = dependency.vpc.outputs.private_subnet_ids
  alb_listener_arn      = dependency.alb.outputs.alb_listener_arn
  alb_security_group_id = dependency.alb.outputs.alb_security_group_id

  # From env.hcl
  environment     = local.environment
  ami_id          = local.ami_id
  artifact_bucket = local.artifact_bucket

  # Network CIDRs
  mongo_cidrs = local.mongo_cidrs
  sql_cidrs   = local.sql_cidrs
  kafka_cidrs = local.kafka_cidrs
  redis_cidrs = local.redis_cidrs

  # Default scaling configuration
  min_size         = local.default_min_size
  max_size         = local.default_max_size
  desired_capacity = local.default_desired_capacity
  instance_type    = local.default_instance_type

  # Autoscaling thresholds
  scale_up_cpu_threshold   = local.scale_up_cpu_threshold
  scale_down_cpu_threshold = local.scale_down_cpu_threshold

  # Optional resources
  s3_logs_bucket = local.s3_logs_bucket

  # Feature flags (defaults - can be overridden per service)
  needs_alb          = true
  needs_mongo        = false
  needs_sql          = false
  needs_redis        = false
  needs_kafka        = true
  needs_https_egress = true
  needs_s3_logs      = true
  needs_dataiku      = false

  # Escape hatches (empty defaults)
  additional_iam_policy_arns    = []
  additional_security_group_ids = []
  environment_variables         = {}
}
