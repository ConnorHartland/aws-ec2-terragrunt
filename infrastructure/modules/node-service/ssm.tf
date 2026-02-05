# SSM Parameters for the service
# These are the base parameters that userdata expects

# App version parameter - controls which version gets deployed
resource "aws_ssm_parameter" "app_version" {
  name        = "/${var.service_name}/${var.environment}/app-version"
  description = "Application version to deploy for ${var.service_name}"
  type        = "String"
  value       = var.app_version
  tags        = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}

# Service-specific parameters from Terraform variables
resource "aws_ssm_parameter" "config" {
  for_each = var.ssm_parameters

  name        = "/${var.service_name}/${var.environment}/${each.key}"
  description = try(each.value.description, "Config parameter for ${var.service_name}")
  type        = try(each.value.secure, false) ? "SecureString" : "String"
  value       = each.value.value
  tags        = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}
