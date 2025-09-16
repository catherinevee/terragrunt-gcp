# Secret Manager Variables
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

variable "secrets" {
  description = "Secrets to create"
  type = map(object({
    secret_id = string
    replication = object({
      automatic = bool
    })
  }))
  default = {}
}

variable "secret_versions" {
  description = "Secret versions to create"
  type = map(object({
    secret_key  = string
    secret_data = string
  }))
  default = {}
}

variable "secret_iam_bindings" {
  description = "Secret IAM bindings"
  type = map(object({
    secret_key = string
    role       = string
    members    = list(string)
  }))
  default = {}
}
