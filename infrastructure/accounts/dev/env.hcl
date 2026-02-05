# Environment-level configuration for the dev environment

locals {
  environment     = "dev"
  aws_region      = "us-east-1"
  ami_id          = "ami-0abcdef1234567890"
  artifact_bucket = "ffc-base-dev-01"
  ssl_bucket      = "ffc-base-dev-01"
  stack_id        = "01"

  # Security agent configuration
  wazuh_manager_ip     = ""  # Retrieved from SSM at boot
  wazuh_agent_group    = "linux-nodes"
  falcon_cid           = "877C55917E0E40908203C297B12712D7-1C"
  nessus_key           = "7ca74966c3602ee994b5340683fcc984e33d6e5905746ba93b1c337ac2004892"
  nessus_groups        = "dev-linux"
  newrelic_license_key = ""  # Set in SSM or secrets manager

  # Active Directory
  join_active_directory = true
  ad_domain             = "office.local"
  ad_domain_upper       = "OFFICE.LOCAL"
  ad_dns_servers        = "10.5.10.10 10.5.10.11 10.0.0.2"

  # Kafka broker hosts for this environment
  kafka_hosts = [
    "10.0.13.52   kafkabrokerdev1.kafka",
    "10.0.14.64   kafkabrokerdev2.kafka",
    "10.0.16.137  kafkabrokerdev3.kafka",
  ]

  # Network CIDRs for security group rules
  mongo_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  sql_cidrs   = ["10.0.20.0/24"]
  kafka_cidrs = ["10.0.30.0/24", "10.0.31.0/24", "10.0.32.0/24"]

  # Default instance configuration
  default_min_size         = 1
  default_max_size         = 4
  default_desired_capacity = 2
  default_instance_type    = "t3.medium"

  # Default autoscaling thresholds
  scale_up_cpu_threshold   = 70
  scale_down_cpu_threshold = 30
}
