# Scale Up Policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${local.name_prefix}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.service.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

# Scale Down Policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${local.name_prefix}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.service.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

# CloudWatch Alarm - CPU High
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  alarm_description   = "Scale up when CPU exceeds ${var.scale_up_cpu_threshold}%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.scale_up_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_up_cpu_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]

  tags = local.common_tags
}

# CloudWatch Alarm - CPU Low
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.name_prefix}-cpu-low"
  alarm_description   = "Scale down when CPU is below ${var.scale_down_cpu_threshold}%"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.scale_down_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_down_cpu_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]

  tags = local.common_tags
}
