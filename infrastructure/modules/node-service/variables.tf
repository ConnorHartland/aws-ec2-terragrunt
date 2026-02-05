# Core service configuration
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

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
  default     = []
}

# EC2/ASG configuration
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

# Application configuration
variable "app_port" {
  description = "Port the application listens on. Set to 0 for Kafka-only services with no HTTP listener."
  type        = number
  default     = 443
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "artifact_bucket" {
  description = "S3 bucket containing deployment artifacts"
  type        = string
}

variable "ssl_bucket" {
  description = "S3 bucket containing SSL certs, Kafka certs, and keytabs"
  type        = string
}

variable "s3_ssl_paths" {
  description = "List of S3 paths (relative to ssl_bucket) for certs/keytabs to pull at boot"
  type        = list(string)
  default     = []
}

variable "wazuh_manager_ip" {
  description = "IP address of the Wazuh manager for agent registration"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener (optional)"
  type        = string
  default     = null
}

variable "path_patterns" {
  description = "URL path patterns for ALB routing"
  type        = list(string)
  default     = ["/*"]
}

# Feature flags
variable "needs_alb" {
  description = "Whether the service needs an Application Load Balancer"
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

variable "needs_kafka" {
  description = "Whether the service needs Kafka access"
  type        = bool
  default     = true
}

variable "needs_https_egress" {
  description = "Whether the service needs HTTPS outbound access"
  type        = bool
  default     = true
}

variable "needs_s3_logs" {
  description = "Whether the service needs S3 access for logs"
  type        = bool
  default     = true
}

# Network CIDRs for security group rules
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

# Escape hatches
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

# Autoscaling configuration
variable "scale_up_cpu_threshold" {
  description = "CPU percentage threshold to trigger scale up"
  type        = number
  default     = 70
}

variable "scale_down_cpu_threshold" {
  description = "CPU percentage threshold to trigger scale down"
  type        = number
  default     = 30
}

variable "scale_up_evaluation_periods" {
  description = "Number of periods to evaluate before scaling up"
  type        = number
  default     = 2
}

variable "scale_down_evaluation_periods" {
  description = "Number of periods to evaluate before scaling down"
  type        = number
  default     = 5
}

# S3 logs bucket (when needs_s3_logs is true)
variable "s3_logs_bucket" {
  description = "S3 bucket for application logs"
  type        = string
  default     = ""
}

# Additional tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Lifecycle hook configuration
variable "enable_lifecycle_hook" {
  description = "Enable lifecycle hook for instance initialization"
  type        = bool
  default     = false
}

variable "lifecycle_hook_timeout" {
  description = "Timeout in seconds for lifecycle hook"
  type        = number
  default     = 300
}

# Stack/deployment identifier
variable "stack_id" {
  description = "Stack identifier (e.g., 01, 02) for hostname generation"
  type        = string
  default     = "01"
}

# /etc/hosts entries
variable "hosts_entries" {
  description = "List of /etc/hosts entries to add (e.g., '10.0.1.1 kafka1.local')"
  type        = list(string)
  default     = []
}

# Active Directory configuration
variable "join_active_directory" {
  description = "Whether to join the instance to Active Directory"
  type        = bool
  default     = false
}

variable "ad_domain" {
  description = "Active Directory domain to join (e.g., office.local)"
  type        = string
  default     = "office.local"
}

variable "ad_domain_upper" {
  description = "Active Directory domain in uppercase (e.g., OFFICE.LOCAL)"
  type        = string
  default     = "OFFICE.LOCAL"
}

variable "ad_dns_servers" {
  description = "Space-separated AD DNS server IPs"
  type        = string
  default     = "10.5.10.10 10.5.10.11"
}

variable "ad_user_ssm_param" {
  description = "SSM parameter name for AD join username"
  type        = string
  default     = "/realm/aduser"
}

variable "ad_pass_ssm_param" {
  description = "SSM parameter name for AD join password"
  type        = string
  default     = "/realm/adpass"
}

# Security agent configuration
variable "falcon_cid" {
  description = "CrowdStrike Falcon CID"
  type        = string
  default     = ""
}

variable "nessus_key" {
  description = "Nessus agent linking key"
  type        = string
  default     = ""
}

variable "nessus_groups" {
  description = "Nessus agent groups"
  type        = string
  default     = ""
}

variable "wazuh_agent_group" {
  description = "Wazuh agent group"
  type        = string
  default     = "default"
}

variable "wazuh_manager_ssm_param" {
  description = "SSM parameter name for Wazuh manager IP"
  type        = string
  default     = "/wazuh/manager"
}

variable "newrelic_license_key" {
  description = "New Relic license key"
  type        = string
  default     = ""
}

# Firewall configuration
variable "nftables_s3_path" {
  description = "S3 path (relative to ssl_bucket) for nftables rules"
  type        = string
  default     = ""
}
