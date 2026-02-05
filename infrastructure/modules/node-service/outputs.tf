# ASG Outputs
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.service.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.service.arn
}

# Security Group Outputs
output "security_group_id" {
  description = "ID of the service security group"
  value       = aws_security_group.service.id
}

output "security_group_name" {
  description = "Name of the service security group"
  value       = aws_security_group.service.name
}

# IAM Outputs
output "instance_role_arn" {
  description = "ARN of the IAM role for instances"
  value       = aws_iam_role.service.arn
}

output "instance_role_name" {
  description = "Name of the IAM role for instances"
  value       = aws_iam_role.service.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.service.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.service.name
}

# ALB Outputs (null if needs_alb is false)
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = var.needs_alb ? aws_lb.service[0].arn : null
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = var.needs_alb ? aws_lb.service[0].dns_name : null
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = var.needs_alb ? aws_lb.service[0].zone_id : null
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = var.needs_alb ? aws_security_group.alb[0].id : null
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = var.needs_alb ? aws_lb_target_group.service[0].arn : null
}

output "target_group_name" {
  description = "Name of the ALB target group"
  value       = var.needs_alb ? aws_lb_target_group.service[0].name : null
}

# Launch Template Outputs
output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.service.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.service.latest_version
}

