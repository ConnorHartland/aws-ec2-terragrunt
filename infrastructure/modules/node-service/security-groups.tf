# -----------------------------------------------------------------------------
# Security Group for Node Service
# -----------------------------------------------------------------------------

resource "aws_security_group" "service" {
  name        = "${var.service_name}-${var.environment}"
  description = "Security group for ${var.service_name} service"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-${var.environment}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Ingress Rules
# -----------------------------------------------------------------------------

# Allow traffic from ALB on app port
resource "aws_security_group_rule" "alb_ingress" {
  count = var.needs_alb ? 1 : 0

  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.service.id
  description              = "Allow traffic from ALB"
}

# -----------------------------------------------------------------------------
# Egress Rules (using for_each pattern)
# -----------------------------------------------------------------------------

locals {
  # Build egress rules map based on feature flags
  egress_rules = merge(
    # HTTPS egress (443)
    var.needs_https_egress ? {
      https = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow HTTPS egress"
      }
    } : {},

    # Kafka egress (9092, 9093, 9094)
    var.needs_kafka && length(var.kafka_cidrs) > 0 ? {
      kafka_9092 = {
        from_port   = 9092
        to_port     = 9092
        protocol    = "tcp"
        cidr_blocks = var.kafka_cidrs
        description = "Allow Kafka plaintext"
      }
      kafka_9093 = {
        from_port   = 9093
        to_port     = 9093
        protocol    = "tcp"
        cidr_blocks = var.kafka_cidrs
        description = "Allow Kafka SSL"
      }
      kafka_9094 = {
        from_port   = 9094
        to_port     = 9094
        protocol    = "tcp"
        cidr_blocks = var.kafka_cidrs
        description = "Allow Kafka SASL"
      }
    } : {},

    # MongoDB egress (27017)
    var.needs_mongo && length(var.mongo_cidrs) > 0 ? {
      mongo = {
        from_port   = 27017
        to_port     = 27017
        protocol    = "tcp"
        cidr_blocks = var.mongo_cidrs
        description = "Allow MongoDB access"
      }
    } : {},

    # SQL egress (5432 for PostgreSQL, 3306 for MySQL)
    var.needs_sql && length(var.sql_cidrs) > 0 ? {
      postgres = {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = var.sql_cidrs
        description = "Allow PostgreSQL access"
      }
      mysql = {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = var.sql_cidrs
        description = "Allow MySQL access"
      }
    } : {},

    # Redis egress (6379)
    var.needs_redis && length(var.redis_cidrs) > 0 ? {
      redis = {
        from_port   = 6379
        to_port     = 6379
        protocol    = "tcp"
        cidr_blocks = var.redis_cidrs
        description = "Allow Redis access"
      }
    } : {}
  )
}

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

# Allow HTTP egress for package managers and health checks
resource "aws_security_group_rule" "http_egress" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service.id
  description       = "Allow HTTP egress"
}
