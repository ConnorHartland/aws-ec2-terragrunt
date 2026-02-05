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

  # SSM parameters (created by Terraform)
  ssm_parameters = {
    MONGO_URI = {
      value       = "mongodb://mongo.dev.internal:27017/usersvc"
      description = "MongoDB connection string"
      secure      = true
    }
    KAFKA_BROKERS = {
      value       = "kafkabrokerdev1.kafka:9092,kafkabrokerdev2.kafka:9092,kafkabrokerdev3.kafka:9092"
      description = "Kafka broker list"
    }
  }

  # Environment variables (baked into launch template)
  environment_variables = {
    NODE_ENV              = "development"
    MONGO_CONNECTION_POOL = "10"
  }

  tags = {
    Team    = "platform"
    Service = "user-management"
  }
}
