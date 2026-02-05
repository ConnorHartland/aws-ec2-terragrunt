# Terragrunt configuration for api-usersvc in dev environment

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/node-service.hcl"
  merge_strategy = "deep"
}

inputs = {
  service_name = "api-usersvc"

  # Instance configuration
  instance_type    = "t3.large"
  min_size         = 2
  max_size         = 10
  desired_capacity = 3

  # Feature flags
  needs_mongo = true
  needs_kafka = true

  # Application configuration
  app_port          = 3000
  health_check_path = "/api/health"
  path_patterns     = ["/api/users/*", "/api/auth/*"]

  # SSL certs to pull at boot (in addition to defaults)
  s3_ssl_paths = [
    "ssl/wildcard/wildcard.foundationfinance.com.crt",
    "ssl/wildcard/wildcard.foundationfinance.com.key",
    "ssl/kafka/root.crt",
    "ssl/kafka/api-usersvc/client.crt",
    "ssl/kafka/api-usersvc/client.key",
  ]

  # Environment variables (baked into launch template)
  # Note: Application secrets (MONGO_URI, KAFKA_BROKERS, etc.) are now managed
  # in S3 at s3://{artifact_bucket}/{service_name}/{environment}/.env
  environment_variables = {
    NODE_ENV              = "development"
    MONGO_CONNECTION_POOL = "10"
  }

  tags = {
    Team    = "platform"
    Service = "user-management"
  }
}
