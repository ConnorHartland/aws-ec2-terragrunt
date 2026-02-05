# Data sources
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Launch Template
resource "aws_launch_template" "service" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.service.arn
  }

  vpc_security_group_ids = concat(
    [aws_security_group.service.id],
    var.additional_security_group_ids
  )

  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh.tpl", {
    # Core
    service_name          = var.service_name
    environment           = var.environment
    aws_region            = data.aws_region.current.id
    stack_id              = var.stack_id
    app_port              = var.app_port
    health_check_path     = var.health_check_path
    env_vars              = local.env_vars_string
    enable_lifecycle_hook = var.enable_lifecycle_hook

    # S3 buckets and paths
    artifact_bucket = var.artifact_bucket
    ssl_bucket      = var.ssl_bucket
    s3_ssl_paths    = var.s3_ssl_paths

    # /etc/hosts entries
    hosts_entries = var.hosts_entries

    # Active Directory
    join_active_directory = var.join_active_directory
    ad_domain             = var.ad_domain
    ad_domain_upper       = var.ad_domain_upper
    ad_dns_servers        = var.ad_dns_servers
    ad_user_ssm_param     = var.ad_user_ssm_param
    ad_pass_ssm_param     = var.ad_pass_ssm_param

    # Security agents
    falcon_cid              = var.falcon_cid
    nessus_key              = var.nessus_key
    nessus_groups           = var.nessus_groups
    wazuh_manager_ip        = var.wazuh_manager_ip
    wazuh_manager_ssm_param = var.wazuh_manager_ssm_param
    wazuh_agent_group       = var.wazuh_agent_group
    newrelic_license_key    = var.newrelic_license_key

    # Firewall
    nftables_s3_path = var.nftables_s3_path
  }))

  # Require IMDSv2 for enhanced security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # EBS optimization
  ebs_optimized = true

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Tag specifications for instances
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-instance"
    })
  }

  # Tag specifications for volumes
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-volume"
    })
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}
