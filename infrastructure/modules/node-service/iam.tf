# -----------------------------------------------------------------------------
# IAM Role for EC2 Instances
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "service" {
  name               = "${var.service_name}-${var.environment}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = local.common_tags
}

resource "aws_iam_instance_profile" "service" {
  name = "${var.service_name}-${var.environment}-profile"
  role = aws_iam_role.service.name

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Base IAM Policy (always attached)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "base" {
  # CloudWatch Logs permissions
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.service_name}*",
      "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.service_name}*:*"
    ]
  }

  # SSM Parameter Store read access
  statement {
    sid    = "SSMParameterStore"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/${var.service_name}/*"
    ]
  }

  # EC2 describe permissions for instance metadata
  statement {
    sid    = "EC2Describe"
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  # Artifact bucket read access
  statement {
    sid    = "ArtifactBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.artifact_bucket}",
      "arn:aws:s3:::${var.artifact_bucket}/${var.service_name}/*"
    ]
  }

  # CloudWatch metrics permissions
  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["CWAgent", "NodeServices/${var.service_name}"]
    }
  }

  # ASG lifecycle hook completion (if enabled)
  dynamic "statement" {
    for_each = var.enable_lifecycle_hook ? [1] : []
    content {
      sid    = "ASGLifecycleHook"
      effect = "Allow"
      actions = [
        "autoscaling:CompleteLifecycleAction"
      ]
      resources = [
        "arn:aws:autoscaling:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.service_name}-${var.environment}-asg"
      ]
    }
  }
}

resource "aws_iam_role_policy" "base" {
  name   = "base-policy"
  role   = aws_iam_role.service.id
  policy = data.aws_iam_policy_document.base.json
}

# -----------------------------------------------------------------------------
# Conditional IAM Policies
# -----------------------------------------------------------------------------

# S3 Logs bucket policy
data "aws_iam_policy_document" "s3_logs" {
  count = var.needs_s3_logs && var.s3_logs_bucket != "" ? 1 : 0

  statement {
    sid    = "S3LogsWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_logs_bucket}/${var.service_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "s3_logs" {
  count = var.needs_s3_logs && var.s3_logs_bucket != "" ? 1 : 0

  name   = "s3-logs-policy"
  role   = aws_iam_role.service.id
  policy = data.aws_iam_policy_document.s3_logs[0].json
}

# Redis/ElastiCache policy
data "aws_iam_policy_document" "redis" {
  count = var.needs_redis ? 1 : 0

  statement {
    sid    = "ElastiCacheDescribe"
    effect = "Allow"
    actions = [
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeReplicationGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "redis" {
  count = var.needs_redis ? 1 : 0

  name   = "redis-policy"
  role   = aws_iam_role.service.id
  policy = data.aws_iam_policy_document.redis[0].json
}

# Dataiku API policy
data "aws_iam_policy_document" "dataiku" {
  count = var.needs_dataiku ? 1 : 0

  statement {
    sid    = "DataikuSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/dataiku/*"
    ]
  }
}

resource "aws_iam_role_policy" "dataiku" {
  count = var.needs_dataiku ? 1 : 0

  name   = "dataiku-policy"
  role   = aws_iam_role.service.id
  policy = data.aws_iam_policy_document.dataiku[0].json
}

# -----------------------------------------------------------------------------
# AWS Managed Policy Attachments
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# -----------------------------------------------------------------------------
# Additional Policy Attachments (escape hatch)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_iam_policy_arns)

  role       = aws_iam_role.service.name
  policy_arn = each.value
}
