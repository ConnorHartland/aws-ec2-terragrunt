# IAM Role for EC2 instances
resource "aws_iam_role" "service" {
  name_prefix = "${local.name_prefix}-"
  path        = "/services/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "service" {
  name_prefix = "${local.name_prefix}-"
  path        = "/services/"
  role        = aws_iam_role.service.name
  tags        = local.common_tags
}

# Base inline policy - common permissions for all services
resource "aws_iam_role_policy" "base" {
  name_prefix = "${local.name_prefix}-base-"
  role        = aws_iam_role.service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.service.arn}",
          "${aws_cloudwatch_log_group.service.arn}:*"
        ]
      },
      # EC2 describe permissions (for service discovery)
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      # Artifact bucket read access
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.artifact_bucket}",
          "arn:aws:s3:::${var.artifact_bucket}/*"
        ]
      },
      # Parameter Store read access for service config
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/${var.service_name}/*",
          "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/shared/*"
        ]
      },
      # KMS decrypt for encrypted parameters
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "ssm.${data.aws_region.current.id}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# S3 Logs policy (conditional)
resource "aws_iam_role_policy" "s3_logs" {
  count = var.needs_s3_logs && var.s3_logs_bucket != "" ? 1 : 0

  name_prefix = "${local.name_prefix}-s3-logs-"
  role        = aws_iam_role.service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_logs_bucket}/${var.service_name}/*"
        ]
      }
    ]
  })
}

# Redis/ElastiCache policy (conditional)
resource "aws_iam_role_policy" "redis" {
  count = var.needs_redis ? 1 : 0

  name_prefix = "${local.name_prefix}-redis-"
  role        = aws_iam_role.service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Dataiku S3 policy (conditional)
resource "aws_iam_role_policy" "dataiku" {
  count = var.needs_dataiku && var.dataiku_bucket != "" ? 1 : 0

  name_prefix = "${local.name_prefix}-dataiku-"
  role        = aws_iam_role.service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.dataiku_bucket}",
          "arn:aws:s3:::${var.dataiku_bucket}/*"
        ]
      }
    ]
  })
}

# Lifecycle hook policy (conditional)
resource "aws_iam_role_policy" "lifecycle_hook" {
  count = var.enable_lifecycle_hook ? 1 : 0

  name_prefix = "${local.name_prefix}-lifecycle-"
  role        = aws_iam_role.service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:RecordLifecycleActionHeartbeat"
        ]
        Resource = aws_autoscaling_group.service.arn
      }
    ]
  })
}

# AWS Managed Policy: SSM for Session Manager access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AWS Managed Policy: CloudWatch Agent
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Additional policy attachments (escape hatch)
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_iam_policy_arns)

  role       = aws_iam_role.service.name
  policy_arn = each.value
}
