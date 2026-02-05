# Security Group for the service instances
resource "aws_security_group" "service" {
  name_prefix = "${local.name_prefix}-"
  description = "Security group for ${var.service_name} service"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress rule from ALB (conditional)
resource "aws_security_group_rule" "ingress_from_alb" {
  count = var.needs_alb ? 1 : 0

  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  security_group_id        = aws_security_group.service.id
  description              = "Allow traffic from ALB"
}

# Build egress rules map based on feature flags
locals {
  egress_rules = merge(
    # HTTPS egress (for external API calls)
    var.needs_https_egress ? {
      https = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS outbound"
      }
    } : {},

    # HTTP egress (for package managers, etc.)
    var.needs_https_egress ? {
      http = {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP outbound"
      }
    } : {},

    # Kafka egress
    var.needs_kafka && length(var.kafka_cidrs) > 0 ? {
      kafka = {
        from_port   = 9092
        to_port     = 9094
        protocol    = "tcp"
        cidr_blocks = var.kafka_cidrs
        description = "Kafka broker access"
      }
    } : {},

    # MongoDB egress
    var.needs_mongo && length(var.mongo_cidrs) > 0 ? {
      mongo = {
        from_port   = 27017
        to_port     = 27017
        protocol    = "tcp"
        cidr_blocks = var.mongo_cidrs
        description = "MongoDB access"
      }
    } : {},

    # SQL egress (PostgreSQL)
    var.needs_sql && length(var.sql_cidrs) > 0 ? {
      postgresql = {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = var.sql_cidrs
        description = "PostgreSQL access"
      }
    } : {},

    # SQL egress (MySQL)
    var.needs_sql && length(var.sql_cidrs) > 0 ? {
      mysql = {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = var.sql_cidrs
        description = "MySQL access"
      }
    } : {},

    # Redis egress
    var.needs_redis && length(var.redis_cidrs) > 0 ? {
      redis = {
        from_port   = 6379
        to_port     = 6379
        protocol    = "tcp"
        cidr_blocks = var.redis_cidrs
        description = "Redis access"
      }
    } : {},

    # Dataiku egress
    var.needs_dataiku && length(var.dataiku_cidrs) > 0 ? {
      dataiku = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = var.dataiku_cidrs
        description = "Dataiku API access"
      }
    } : {}
  )
}

# Dynamic egress rules using for_each
resource "aws_security_group_rule" "egress" {
  for_each = local.egress_rules

  type              = "egress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  security_group_id = aws_security_group.service.id
  description       = each.value.description
}

# DNS egress (always needed)
resource "aws_security_group_rule" "egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service.id
  description       = "DNS UDP outbound"
}

resource "aws_security_group_rule" "egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service.id
  description       = "DNS TCP outbound"
}
