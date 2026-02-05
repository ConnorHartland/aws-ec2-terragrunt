# -----------------------------------------------------------------------------
# API User Service Configuration
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/node-service.hcl"
  merge_strategy = "deep"
}

inputs = {
  service_name  = "api-usersvc"
  instance_type = "t3.large"
  min_size      = 2
  max_size      = 10

  # Feature flags for this service
  needs_mongo = true
  needs_redis = true

  # ALB routing configuration
  path_patterns         = ["/api/users/*", "/api/auth/*"]
  health_check_path     = "/api/health"
  listener_rule_priority = 100

  # Application configuration
  environment_variables = {
    NODE_ENV  = "development"
    LOG_LEVEL = "debug"
  }
}
