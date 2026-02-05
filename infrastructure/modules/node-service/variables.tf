# -----------------------------------------------------------------------------
# Core Variables
# -----------------------------------------------------------------------------

variable "service_name" {
  description = "Name of the Node.js service"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ASG"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "app_port" {
  description = "Port the Node.js application listens on"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "path_patterns" {
  description = "URL path patterns for ALB listener rule"
  type        = list(string)
  default     = ["/*"]
}

variable "artifact_bucket" {
  description = "S3 bucket containing deployment artifacts"
  type        = string
}

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------

variable "needs_alb" {
  description = "Whether the service needs ALB integration"
  type        = bool
  default     = true
}

variable "needs_mongo" {
  description = "Whether the service needs MongoDB access"
  type        = bool
  default     = false
}

variable "needs_sql" {
  description = "Whether the service needs SQL database access"
  type        = bool
  default     = false
}

variable "needs_redis" {
  description = "Whether the service needs Redis access"
  type        = bool
  default     = false
}

variable "needs_kafka" {
  description = "Whether the service needs Kafka access"
  type        = bool
  default     = true
}

variable "needs_https_egress" {
  description = "Whether the service needs HTTPS egress"
  type        = bool
  default     = true
}

variable "needs_s3_logs" {
  description = "Whether the service needs S3 log bucket access"
  type        = bool
  default     = true
}

variable "needs_dataiku" {
  description = "Whether the service needs Dataiku API access"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Network CIDRs
# -----------------------------------------------------------------------------

variable "mongo_cidrs" {
  description = "CIDR blocks for MongoDB access"
  type        = list(string)
  default     = []
}

variable "sql_cidrs" {
  description = "CIDR blocks for SQL database access"
  type        = list(string)
  default     = []
}

variable "kafka_cidrs" {
  description = "CIDR blocks for Kafka access"
  type        = list(string)
  default     = []
}

variable "redis_cidrs" {
  description = "CIDR blocks for Redis access"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# ALB Configuration
# -----------------------------------------------------------------------------

variable "alb_listener_arn" {
  description = "ARN of the ALB listener for adding rules"
  type        = string
  default     = ""
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
  default     = ""
}

variable "listener_rule_priority" {
  description = "Priority for the ALB listener rule (must be unique per listener)"
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# Escape Hatches
# -----------------------------------------------------------------------------

variable "additional_iam_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the instance role"
  type        = list(string)
  default     = []
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to instances"
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Environment variables to pass to the application"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Autoscaling Configuration
# -----------------------------------------------------------------------------

variable "scale_up_cpu_threshold" {
  description = "CPU utilization threshold for scaling up"
  type        = number
  default     = 70
}

variable "scale_down_cpu_threshold" {
  description = "CPU utilization threshold for scaling down"
  type        = number
  default     = 30
}

variable "scale_up_evaluation_periods" {
  description = "Number of periods to evaluate for scale up"
  type        = number
  default     = 2
}

variable "scale_down_evaluation_periods" {
  description = "Number of periods to evaluate for scale down"
  type        = number
  default     = 5
}

variable "scale_cooldown" {
  description = "Cooldown period in seconds between scaling actions"
  type        = number
  default     = 300
}

# -----------------------------------------------------------------------------
# Optional Configuration
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "s3_logs_bucket" {
  description = "S3 bucket for application logs"
  type        = string
  default     = ""
}

variable "dataiku_api_endpoint" {
  description = "Dataiku API endpoint URL"
  type        = string
  default     = ""
}

variable "enable_lifecycle_hook" {
  description = "Enable ASG lifecycle hook for instance initialization"
  type        = bool
  default     = false
}

variable "lifecycle_hook_timeout" {
  description = "Timeout in seconds for lifecycle hook"
  type        = number
  default     = 300
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of the root EBS volume"
  type        = string
  default     = "gp3"
}
