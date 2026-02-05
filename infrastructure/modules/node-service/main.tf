# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Launch Template
# -----------------------------------------------------------------------------

resource "aws_launch_template" "service" {
  name        = "${var.service_name}-${var.environment}-lt"
  description = "Launch template for ${var.service_name} service"

  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.service.arn
  }

  vpc_security_group_ids = concat(
    [aws_security_group.service.id],
    var.additional_security_group_ids
  )

  # IMDSv2 required for security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  # User data script
  user_data = base64encode(templatefile(
    "${path.module}/templates/userdata.sh.tpl",
    {
      service_name           = var.service_name
      environment            = var.environment
      aws_region             = data.aws_region.current.id
      app_port               = var.app_port
      artifact_bucket        = var.artifact_bucket
      environment_variables  = var.environment_variables
      enable_lifecycle_hook  = var.enable_lifecycle_hook
      asg_name               = "${var.service_name}-${var.environment}-asg"
    }
  ))

  # Tag specifications for instances
  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
      Name = "${var.service_name}-${var.environment}"
    })
  }

  # Tag specifications for volumes
  tag_specifications {
    resource_type = "volume"

    tags = merge(local.common_tags, {
      Name = "${var.service_name}-${var.environment}-volume"
    })
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}
