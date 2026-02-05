# Data source for subnet AZ lookup
data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

# Auto Scaling Group
resource "aws_autoscaling_group" "service" {
  name_prefix         = "${local.name_prefix}-"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  # Health check configuration
  health_check_type         = var.needs_alb ? "ELB" : "EC2"
  health_check_grace_period = 300

  # Launch template reference
  launch_template {
    id      = aws_launch_template.service.id
    version = "$Latest"
  }

  # Instance refresh for rolling deployments
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  # Wait for instances to be healthy before considering deployment complete
  wait_for_capacity_timeout = "10m"

  # Termination policies
  termination_policies = ["OldestLaunchTemplate", "OldestInstance"]

  # Protect from scale-in during deployments
  protect_from_scale_in = false

  # Enable metrics collection
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  # Dynamic target group attachment
  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# Lifecycle hook for instance initialization (conditional)
resource "aws_autoscaling_lifecycle_hook" "launch" {
  count = var.enable_lifecycle_hook ? 1 : 0

  name                   = "${local.name_prefix}-launch-hook"
  autoscaling_group_name = aws_autoscaling_group.service.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  default_result         = "ABANDON"
  heartbeat_timeout      = var.lifecycle_hook_timeout
}

# Target group attachment (conditional on ALB)
resource "aws_autoscaling_attachment" "alb" {
  count = var.needs_alb ? 1 : 0

  autoscaling_group_name = aws_autoscaling_group.service.name
  lb_target_group_arn    = aws_lb_target_group.service[0].arn
}
