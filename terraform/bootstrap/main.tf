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
# CloudWatch log group for pipeline logs, one log stream per process.
# Kept in bootstrap so the pipeline's destroy job never deletes it.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "pipeline" {
  name              = var.pipeline_log_group_name
  retention_in_days = var.pipeline_log_retention_days

  tags = { Component = "ci-cd-logs" }
}

# Lets the pipeline role write its logs, even if PowerUserAccess is removed.
data "aws_iam_policy_document" "pipeline_logs" {
  statement {
    sid       = "WritePipelineLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.pipeline.arn}:*"]
  }
}

resource "aws_iam_role_policy" "pipeline_logs" {
  name   = "pipeline-cloudwatch-logs"
  role   = local.role_name
  policy = data.aws_iam_policy_document.pipeline_logs.json

  depends_on = [module.github_oidc]
}
