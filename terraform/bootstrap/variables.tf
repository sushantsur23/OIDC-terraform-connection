variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
}

variable "project" {
  description = "Project name; prefixes all resource names."
  type        = string
}

variable "environment" {
  description = "Environment name; also the GitHub Environment allowed to deploy."
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owner tag."
  type        = string
}

variable "cost_center" {
  description = "CostCenter tag."
  type        = string
}

variable "github_repository" {
  description = "GitHub repo in owner/name form."
  type        = string
}

variable "github_subject_repository" {
  description = "Repo identifier in the GitHub OIDC sub claim, e.g. owner@ownerId/repo@repoId. Null uses github_repository."
  type        = string
  default     = null
}

variable "create_oidc_provider" {
  description = "Set false if the GitHub OIDC provider already exists in this account."
  type        = bool
  default     = true
}

variable "state_bucket" {
  description = "Terraform state bucket."
  type        = string
  default     = "remote-test-sushant"
}

variable "state_prefix" {
  description = "State directory the pipeline may access."
  type        = string
  default     = "prod/terraform-lock"
}

variable "pipeline_log_group_name" {
  description = "CloudWatch log group that receives pipeline logs."
  type        = string
  default     = "test_group"
}

variable "pipeline_log_retention_days" {
  description = "Days to keep pipeline logs."
  type        = number
  default     = 30
}
