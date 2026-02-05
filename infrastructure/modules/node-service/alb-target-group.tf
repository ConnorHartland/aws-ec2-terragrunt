# -----------------------------------------------------------------------------
# ALB Target Group (conditional)
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "service" {
  count = var.needs_alb ? 1 : 0

  name     = "${var.service_name}-${var.environment}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-${var.environment}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# ALB Listener Rule (conditional)
# -----------------------------------------------------------------------------

resource "aws_lb_listener_rule" "service" {
  count = var.needs_alb ? 1 : 0

  listener_arn = var.alb_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# ASG Target Group Attachment (conditional)
# -----------------------------------------------------------------------------

resource "aws_autoscaling_attachment" "service" {
  count = var.needs_alb ? 1 : 0

  autoscaling_group_name = aws_autoscaling_group.service.name
  lb_target_group_arn    = aws_lb_target_group.service[0].arn
}
