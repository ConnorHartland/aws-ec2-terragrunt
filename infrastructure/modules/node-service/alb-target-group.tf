# ALB Security Group
resource "aws_security_group" "alb" {
  count = var.needs_alb ? 1 : 0

  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for ${var.service_name} ALB"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Security Group - Ingress HTTP
resource "aws_security_group_rule" "alb_ingress_http" {
  count = var.needs_alb ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb[0].id
  description       = "HTTP from anywhere"
}

# ALB Security Group - Ingress HTTPS
resource "aws_security_group_rule" "alb_ingress_https" {
  count = var.needs_alb && var.certificate_arn != null ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb[0].id
  description       = "HTTPS from anywhere"
}

# ALB Security Group - Egress to service
resource "aws_security_group_rule" "alb_egress_service" {
  count = var.needs_alb ? 1 : 0

  type                     = "egress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.service.id
  security_group_id        = aws_security_group.alb[0].id
  description              = "To service instances"
}

# Application Load Balancer
resource "aws_lb" "service" {
  count = var.needs_alb ? 1 : 0

  name_prefix        = substr(var.service_name, 0, 6)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# Target Group
resource "aws_lb_target_group" "service" {
  count = var.needs_alb ? 1 : 0

  name_prefix = substr(var.service_name, 0, 6)
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  count = var.needs_alb ? 1 : 0

  load_balancer_arn = aws_lb.service[0].arn
  port              = 80
  protocol          = "HTTP"

  # Redirect to HTTPS if certificate is provided, otherwise forward to target group
  dynamic "default_action" {
    for_each = var.certificate_arn != null ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.service[0].arn
    }
  }

  tags = local.common_tags
}

# HTTPS Listener (conditional on certificate)
resource "aws_lb_listener" "https" {
  count = var.needs_alb && var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.service[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }

  tags = local.common_tags
}
