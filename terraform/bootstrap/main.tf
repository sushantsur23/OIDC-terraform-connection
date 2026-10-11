# Run ONCE from your machine with admin credentials. It creates the IAM role
# that GitHub Actions assumes via OIDC; after that, the pipeline runs
# environments/prod without any stored AWS keys.

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Repository  = var.github_repository
    Stack       = "bootstrap"
  }

  role_name = "${var.project}-${var.environment}-github-actions"
}

module "github_oidc" {
  source = "../modules/github-oidc"

  github_repository         = var.github_repository
  github_subject_repository = var.github_subject_repository
  role_name                 = local.role_name
  create_oidc_provider      = var.create_oidc_provider
  allowed_branches          = ["main"]
  allowed_environments      = [var.environment]
  allow_pull_requests       = true

  state_bucket         = var.state_bucket
  state_prefix         = var.state_prefix
  resource_name_prefix = var.project

  tags = { Component = "ci-cd" }
}

# ---------------------------------------------------------------------------
# Pipeline logs: scripts/run-logged.sh creates the CloudWatch log group on
# first use and writes one log stream per process. This policy keeps that
# working even if PowerUserAccess is removed from the role. The log group
# lives in this stack's region, which must match LOG_REGION in the workflow.
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  pipeline_log_group_arn = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.pipeline_log_group_name}"
}

data "aws_iam_policy_document" "pipeline_logs" {
  statement {
    sid       = "ManagePipelineLogGroup"
    actions   = ["logs:CreateLogGroup", "logs:PutRetentionPolicy", "logs:DescribeLogGroups"]
    resources = [local.pipeline_log_group_arn, "${local.pipeline_log_group_arn}:*"]
  }

  statement {
    sid       = "WritePipelineLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${local.pipeline_log_group_arn}:*"]
  }
}

resource "aws_iam_role_policy" "pipeline_logs" {
  name   = "pipeline-cloudwatch-logs"
  role   = local.role_name
  policy = data.aws_iam_policy_document.pipeline_logs.json

  depends_on = [module.github_oidc]
}
