# IAM Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "org_id" {
  description = "The GCP organization ID"
  type        = string
  default     = ""
}

variable "service_accounts" {
  description = "Map of service accounts to create"
  type = map(object({
    display_name               = string
    description               = optional(string)
    create_key                = optional(bool)
    store_key_in_secret_manager = optional(bool)
  }))
  default = {}
}

variable "project_iam_bindings" {
  description = "Map of project-level IAM bindings"
  type = map(object({
    role                   = string
    members               = list(string)
    condition_title       = optional(string)
    condition_description = optional(string)
    condition_expression  = optional(string)
  }))
  default = {}
}

variable "service_account_iam_bindings" {
  description = "Map of service account IAM bindings"
  type = map(object({
    service_account = string
    role           = string
    members        = list(string)
  }))
  default = {}
}

variable "workload_identity_bindings" {
  description = "Map of Workload Identity bindings for GKE"
  type = map(object({
    service_account = string
    namespace      = string
    ksa_name       = string
  }))
  default = {}
}

variable "custom_roles" {
  description = "Map of custom IAM roles to create"
  type = map(object({
    title       = string
    description = string
    permissions = list(string)
    stage      = optional(string)
  }))
  default = {}
}

variable "folder_iam_bindings" {
  description = "Map of folder-level IAM bindings"
  type = map(object({
    folder  = string
    role    = string
    members = list(string)
  }))
  default = {}
}

variable "organization_iam_bindings" {
  description = "Map of organization-level IAM bindings"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

variable "audit_configs" {
  description = "Map of audit configurations by service"
  type = map(object({
    audit_log_configs = list(object({
      log_type         = string
      exempted_members = optional(list(string))
    }))
  }))
  default = {}
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}