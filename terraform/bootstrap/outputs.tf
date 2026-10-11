output "github_actions_role_arn" {
  description = "Add this as the AWS_ROLE_ARN repository variable in GitHub (Settings > Secrets and variables > Actions > Variables)."
  value       = module.github_oidc.role_arn
}

output "pipeline_log_group_name" {
  description = "CloudWatch log group the pipeline writes to (LOG_GROUP in the workflow)."
  value       = var.pipeline_log_group_name
}
