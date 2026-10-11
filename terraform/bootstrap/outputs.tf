output "github_actions_role_arn" {
  description = "Add this as the AWS_ROLE_ARN variable in GitHub (Settings > Environments > prod)."
  value       = module.github_oidc.role_arn
}

output "pipeline_log_group_name" {
  description = "CloudWatch log group for pipeline logs (LOG_GROUP in the workflow)."
  value       = aws_cloudwatch_log_group.pipeline.name
}
