data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
      Repository  = var.github_repository
    },
    var.extra_tags
  )
}

# ---------------------------------------------------------------------------
# Networking: use the given VPC/subnet, or fall back to the default VPC.
# For real production workloads, give this a dedicated VPC with private subnets.
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_id == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  vpc_id    = coalesce(var.vpc_id, try(data.aws_vpc.default[0].id, null))
  subnet_id = coalesce(var.subnet_id, try(sort(data.aws_subnets.default[0].ids)[0], null))
}

# ---------------------------------------------------------------------------
# S3 buckets (one module call per entry in var.s3_buckets)
# ---------------------------------------------------------------------------
module "s3" {
  source   = "../../modules/s3"
  for_each = var.s3_buckets

  # Account ID suffix keeps names globally unique.
  bucket_name                        = "${local.name_prefix}-${each.key}-${data.aws_caller_identity.current.account_id}"
  versioning_enabled                 = each.value.versioning_enabled
  noncurrent_version_expiration_days = each.value.noncurrent_version_expiration_days

  tags = { Component = "storage", Purpose = each.value.purpose }
}

# ---------------------------------------------------------------------------
# Secrets Manager — values are filled in manually, never in code.
# ---------------------------------------------------------------------------
module "app_secret" {
  source = "../../modules/secrets-manager"

  name        = "${var.project}/${var.environment}/app-config"
  description = "Application configuration for ${local.name_prefix}"
  secret_keys = var.secret_keys

  # Delete immediately on destroy, so the next apply can reuse the name.
  recovery_window_in_days = 0

  tags = { Component = "secrets" }
}

# ---------------------------------------------------------------------------
# EC2 instance
# ---------------------------------------------------------------------------
module "ec2" {
  source = "../../modules/ec2"

  name                 = "${local.name_prefix}-app"
  instance_type        = var.instance_type
  vpc_id               = local.vpc_id
  subnet_id            = local.subnet_id
  associate_public_ip  = var.associate_public_ip
  root_volume_size     = var.root_volume_size
  ingress_rules        = var.ingress_rules
  readable_secret_arns = [module.app_secret.secret_arn]

  tags = { Component = "compute" }
}
