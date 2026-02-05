# Terragrunt configuration for api-usersvc in dev environment

# Include root configuration for backend and provider
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include common node-service configuration
include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/node-service.hcl"
  merge_strategy = "deep"
}

# Service-specific inputs (override defaults from envcommon)
inputs = {
  service_name = "api-usersvc"

  # Instance configuration overrides
  instance_type    = "t3.large"
  min_size         = 2
  max_size         = 10
  desired_capacity = 3

  # Feature flags - this service needs MongoDB and Redis
  needs_mongo = true
  needs_redis = true
  needs_kafka = true

  # Application configuration
  app_port          = 3000
  health_check_path = "/api/health"
  path_patterns     = ["/api/users/*", "/api/auth/*"]

  # Environment variables for the application
  environment_variables = {
    NODE_ENV                 = "development"
    LOG_LEVEL                = "debug"
    MONGO_CONNECTION_POOL    = "10"
    REDIS_CONNECTION_TIMEOUT = "5000"
  }

  # Additional tags for this service
  tags = {
    Team    = "platform"
    Service = "user-management"
  }
}
