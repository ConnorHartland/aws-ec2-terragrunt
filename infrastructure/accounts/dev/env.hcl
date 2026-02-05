# -----------------------------------------------------------------------------
# Environment-level Configuration for Development
# -----------------------------------------------------------------------------

locals {
  environment     = "dev"
  aws_region      = "us-east-1"
  ami_id          = "ami-0abcdef1234567890"
  artifact_bucket = "dev-deployment-artifacts"

  # Network CIDRs for external services
  mongo_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  sql_cidrs   = ["10.0.20.0/24"]
  kafka_cidrs = ["10.0.30.0/24", "10.0.31.0/24", "10.0.32.0/24"]
  redis_cidrs = ["10.0.40.0/24"]

  # Default ASG configuration
  default_min_size         = 1
  default_max_size         = 4
  default_desired_capacity = 2
  default_instance_type    = "t3.medium"

  # Autoscaling thresholds
  scale_up_cpu_threshold   = 70
  scale_down_cpu_threshold = 30

  # Optional resources
  s3_logs_bucket = "dev-application-logs"
}
