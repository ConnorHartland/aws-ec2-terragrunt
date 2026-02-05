# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    ServiceName = var.service_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}
