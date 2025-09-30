# IAM Variables
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

variable "service_accounts" {
  description = "Service accounts to create"
  type = map(object({
    account_id   = string
    display_name = string
    description  = string
  }))
  default = {}
}

variable "custom_roles" {
  description = "Custom roles to create"
  type = map(object({
    role_id     = string
    title       = string
    description = string
    permissions = list(string)
  }))
  default = {}
}

variable "service_account_roles" {
  description = "Service account role bindings"
  type = map(object({
    role                = string
    service_account_key = string
  }))
  default = {}
}

variable "project_iam_bindings" {
  description = "Project IAM bindings"
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}

variable "enable_workload_identity" {
  description = "Enable workload identity"
  type        = bool
  default     = false
}

variable "workload_identity_pool_id" {
  description = "Workload identity pool ID"
  type        = string
  default     = ""
}

variable "workload_identity_display_name" {
  description = "Workload identity pool display name"
  type        = string
  default     = ""
}

variable "workload_identity_description" {
  description = "Workload identity pool description"
  type        = string
  default     = ""
}

variable "workload_identity_pool_provider_id" {
  description = "Workload identity pool provider ID"
  type        = string
  default     = ""
}

variable "workload_identity_provider_display_name" {
  description = "Workload identity provider display name"
  type        = string
  default     = ""
}

variable "workload_identity_provider_description" {
  description = "Workload identity provider description"
  type        = string
  default     = ""
}

variable "oidc_issuer_uri" {
  description = "OIDC issuer URI"
  type        = string
  default     = ""
}

variable "oidc_allowed_audiences" {
  description = "OIDC allowed audiences"
  type        = list(string)
  default     = []
}

variable "folder_id" {
  description = "The folder ID where IAM policies are applied (optional)"
  type        = string
  default     = ""
}

variable "organization_id" {
  description = "The organization ID where IAM policies are applied (optional)"
  type        = string
  default     = ""
}
