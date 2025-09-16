# KMS Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "key_ring_name" {
  description = "Name of the KMS key ring"
  type        = string
}

variable "crypto_keys" {
  description = "Crypto keys to create"
  type = map(object({
    name             = string
    purpose          = string
    algorithm        = string
    rotation_period  = string
  }))
  default = {}
}

variable "enable_iam_bindings" {
  description = "Enable IAM bindings for crypto keys"
  type        = bool
  default     = true
}

variable "crypto_key_iam_bindings" {
  description = "Crypto key IAM bindings"
  type = map(object({
    role           = string
    members        = list(string)
    crypto_key_key = string
  }))
  default = {}
}
