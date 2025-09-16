# Container Registry Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_iam_bindings" {
  description = "Enable IAM bindings (requires elevated permissions)"
  type        = bool
  default     = false
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "repositories" {
  description = "Repositories to create"
  type = map(object({
    repository_id = string
    description   = string
    format        = string
  }))
  default = {}
}

variable "repository_iam_bindings" {
  description = "Repository IAM bindings"
  type = map(object({
    repository_key = string
    role           = string
    members        = list(string)
  }))
  default = {}
}
