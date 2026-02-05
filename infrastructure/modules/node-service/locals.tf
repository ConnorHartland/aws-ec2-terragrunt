locals {
  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    ServiceName = var.service_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  # Resource naming prefix
  name_prefix = "${var.service_name}-${var.environment}"

  # Environment variables for user data template
  env_vars_string = join("\n", [
    for k, v in var.environment_variables : "export ${k}=\"${v}\""
  ])

  # CloudWatch log group name
  log_group_name = "/aws/ec2/${var.service_name}/${var.environment}"
}
