# Data sources
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# CloudWatch Log Group for the service
resource "aws_cloudwatch_log_group" "service" {
  name              = local.log_group_name
  retention_in_days = 30
  tags              = local.common_tags
}

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
    service_name          = var.service_name
    environment           = var.environment
    aws_region            = data.aws_region.current.id
    artifact_bucket       = var.artifact_bucket
    app_port              = var.app_port
    log_group_name        = local.log_group_name
    env_vars              = local.env_vars_string
    enable_lifecycle_hook = var.enable_lifecycle_hook
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
