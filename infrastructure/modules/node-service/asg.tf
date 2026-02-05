# -----------------------------------------------------------------------------
# Data Sources for Subnet AZ Lookup
# -----------------------------------------------------------------------------

data "aws_subnet" "selected" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

# -----------------------------------------------------------------------------
# Auto Scaling Group
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "service" {
  name                = "${var.service_name}-${var.environment}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnet_ids

  # Health check configuration
  health_check_type         = var.needs_alb ? "ELB" : "EC2"
  health_check_grace_period = 300

  # Launch template configuration
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

  # Termination policies
  termination_policies = ["OldestInstance", "Default"]

  # Metrics collection
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

  # Wait for capacity
  wait_for_capacity_timeout = "10m"

  # Tags are handled separately via aws_autoscaling_group_tag
  tag {
    key                 = "Name"
    value               = "${var.service_name}-${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    # Allow external scaling (e.g., scheduled actions, manual scaling)
    ignore_changes = [desired_capacity]
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# ASG Tag Propagation
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group_tag" "common_tags" {
  for_each = local.common_tags

  autoscaling_group_name = aws_autoscaling_group.service.name

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = true
  }
}

# -----------------------------------------------------------------------------
# Lifecycle Hook (optional)
# -----------------------------------------------------------------------------

resource "aws_autoscaling_lifecycle_hook" "launching" {
  count = var.enable_lifecycle_hook ? 1 : 0

  name                   = "${var.service_name}-${var.environment}-launch-hook"
  autoscaling_group_name = aws_autoscaling_group.service.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  default_result         = "CONTINUE"
  heartbeat_timeout      = var.lifecycle_hook_timeout
}
