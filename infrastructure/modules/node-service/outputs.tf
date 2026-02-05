# -----------------------------------------------------------------------------
# ASG Outputs
# -----------------------------------------------------------------------------

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.service.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.service.arn
}

# -----------------------------------------------------------------------------
# Security Group Outputs
# -----------------------------------------------------------------------------

output "security_group_id" {
  description = "ID of the service security group"
  value       = aws_security_group.service.id
}

output "security_group_name" {
  description = "Name of the service security group"
  value       = aws_security_group.service.name
}

# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------

output "instance_role_arn" {
  description = "ARN of the IAM role attached to instances"
  value       = aws_iam_role.service.arn
}

output "instance_role_name" {
  description = "Name of the IAM role attached to instances"
  value       = aws_iam_role.service.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = aws_iam_instance_profile.service.arn
}

# -----------------------------------------------------------------------------
# ALB Outputs (conditional)
# -----------------------------------------------------------------------------

output "target_group_arn" {
  description = "ARN of the target group (null if needs_alb is false)"
  value       = var.needs_alb ? aws_lb_target_group.service[0].arn : null
}

output "target_group_name" {
  description = "Name of the target group (null if needs_alb is false)"
  value       = var.needs_alb ? aws_lb_target_group.service[0].name : null
}

# -----------------------------------------------------------------------------
# Launch Template Outputs
# -----------------------------------------------------------------------------

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.service.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.service.latest_version
}

# -----------------------------------------------------------------------------
# Autoscaling Policy Outputs
# -----------------------------------------------------------------------------

output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  value       = aws_autoscaling_policy.scale_down.arn
}
