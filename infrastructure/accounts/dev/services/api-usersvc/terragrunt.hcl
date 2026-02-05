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

  # Feature flags - this service needs MongoDB and Kafka
  needs_mongo = true
  needs_kafka = true

  # Application configuration
  app_port          = 3000
  health_check_path = "/api/health"
  path_patterns     = ["/api/users/*", "/api/auth/*"]

  # SSL certs and keytabs to pull at boot
  s3_ssl_paths = [
    "certs/wildcard.example.com.crt",
    "private/wildcard.example.com.key",
    "kafka/kafka-client.crt",
    "kafka/kafka-client.key",
    "kafka/kafka-ca.crt",
  ]

  # SSM parameters for the service (created by Terraform)
  ssm_parameters = {
    MONGO_URI = {
      value       = "mongodb://mongo.dev.internal:27017/usersvc"
      description = "MongoDB connection string"
      secure      = true
    }
    KAFKA_BROKERS = {
      value       = "kafka-1.dev.internal:9092,kafka-2.dev.internal:9092"
      description = "Kafka broker list"
    }
    LOG_LEVEL = {
      value = "debug"
    }
  }

  # Environment variables passed directly (non-sensitive, baked into launch template)
  environment_variables = {
    NODE_ENV              = "development"
    MONGO_CONNECTION_POOL = "10"
  }

  # Additional tags for this service
  tags = {
    Team    = "platform"
    Service = "user-management"
  }
}
