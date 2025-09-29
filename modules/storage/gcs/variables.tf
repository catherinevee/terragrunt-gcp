# GCS Bucket Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name" {
  description = "Name of the bucket. If null, will use name_prefix with random suffix"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the bucket"
  type        = string
  default     = "gcs-bucket"
}

variable "location" {
  description = "The location for the bucket"
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "The storage class of the bucket"
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains([
      "STANDARD",
      "MULTI_REGIONAL",
      "REGIONAL",
      "NEARLINE",
      "COLDLINE",
      "ARCHIVE"
    ], var.storage_class)
    error_message = "Invalid storage class specified"
  }
}

variable "force_destroy" {
  description = "Force destroy the bucket even if it contains objects"
  type        = bool
  default     = false
}

variable "uniform_bucket_level_access" {
  description = "Enable uniform bucket-level access"
  type        = bool
  default     = true
}

variable "public_access_prevention" {
  description = "Prevents public access to the bucket"
  type        = string
  default     = "enforced"

  validation {
    condition     = contains(["inherited", "enforced"], var.public_access_prevention)
    error_message = "public_access_prevention must be 'inherited' or 'enforced'"
  }
}

variable "requester_pays" {
  description = "Enables Requester Pays on the bucket"
  type        = bool
  default     = false
}

variable "default_event_based_hold" {
  description = "Enable default event-based hold on newly created objects"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Versioning
variable "versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = null
}

# Lifecycle Rules
variable "lifecycle_rules" {
  description = "Lifecycle rules configuration"
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      created_before             = optional(string)
      custom_time_before         = optional(string)
      days_since_custom_time     = optional(number)
      days_since_noncurrent_time = optional(number)
      noncurrent_time_before     = optional(string)
      num_newer_versions         = optional(number)
      matches_prefix             = optional(list(string))
      matches_suffix             = optional(list(string))
      matches_storage_class      = optional(list(string))
      with_state                 = optional(string)
    })
  }))
  default = []
}

variable "enable_default_lifecycle_rules" {
  description = "Enable default lifecycle rules for cost optimization"
  type        = bool
  default     = false
}

# CORS
variable "cors" {
  description = "CORS configuration for the bucket"
  type = list(object({
    origin          = list(string)
    method          = list(string)
    response_header = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = null
}

variable "enable_default_cors" {
  description = "Enable default CORS configuration"
  type        = bool
  default     = false
}

# Website
variable "website" {
  description = "Website configuration for the bucket"
  type = object({
    main_page_suffix = string
    not_found_page   = optional(string)
  })
  default = null
}

variable "enable_website" {
  description = "Enable website hosting"
  type        = bool
  default     = false
}

variable "website_main_page_suffix" {
  description = "Main page suffix for website hosting"
  type        = string
  default     = "index.html"
}

variable "website_not_found_page" {
  description = "404 page for website hosting"
  type        = string
  default     = "404.html"
}

# Retention Policy
variable "retention_policy" {
  description = "Retention policy configuration"
  type = object({
    retention_period = number
    is_locked        = optional(bool)
  })
  default = null
}

variable "retention_days" {
  description = "Number of days to retain objects"
  type        = number
  default     = null
}

variable "retention_policy_is_locked" {
  description = "Lock the retention policy"
  type        = bool
  default     = false
}

# Encryption
variable "encryption" {
  description = "Encryption configuration"
  type = object({
    default_kms_key_name = string
  })
  default = null
}

variable "kms_key_name" {
  description = "KMS key name for encryption"
  type        = string
  default     = null
}

# Logging
variable "logging" {
  description = "Access logging configuration"
  type = object({
    log_bucket        = string
    log_object_prefix = optional(string)
  })
  default = null
}

# Autoclass
variable "autoclass" {
  description = "Autoclass configuration"
  type = object({
    enabled                = bool
    terminal_storage_class = optional(string)
  })
  default = null
}

# Custom Placement
variable "custom_placement_config" {
  description = "Custom placement configuration for dual-region buckets"
  type = object({
    data_locations = list(string)
  })
  default = null
}

# Labels
variable "labels" {
  description = "Labels to apply to the bucket"
  type        = map(string)
  default     = {}
}

# IAM
variable "iam_policy" {
  description = "IAM policy document for the bucket"
  type        = string
  default     = null
}

variable "iam_bindings" {
  description = "IAM role bindings for the bucket"
  type        = map(list(string))
  default     = {}
}

variable "iam_binding_conditions" {
  description = "Conditions for IAM bindings"
  type = map(object({
    title       = string
    description = optional(string)
    expression  = string
  }))
  default = {}
}

variable "iam_members" {
  description = "Individual IAM member bindings"
  type = map(object({
    role   = string
    member = string
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  default = {}
}

# ACLs (when not using uniform bucket level access)
variable "predefined_acl" {
  description = "Predefined ACL to apply"
  type        = string
  default     = null
}

variable "role_entities" {
  description = "Role/entity pairs for bucket ACL"
  type = list(object({
    role   = string
    entity = string
  }))
  default = []
}

variable "default_acl" {
  description = "Default object ACL role/entity pairs"
  type = list(object({
    role   = string
    entity = string
  }))
  default = []
}

# Objects
variable "objects" {
  description = "Map of objects to create in the bucket"
  type = map(object({
    source              = optional(string)
    content             = optional(string)
    content_type        = optional(string)
    storage_class       = optional(string)
    cache_control       = optional(string)
    content_disposition = optional(string)
    content_encoding    = optional(string)
    content_language    = optional(string)
    event_based_hold    = optional(bool)
    temporary_hold      = optional(bool)
    kms_key_name        = optional(string)
    metadata            = optional(map(string))
  }))
  default = {}
}

# Notifications
variable "notifications" {
  description = "Pub/Sub notifications configuration"
  type = map(object({
    topic              = string
    payload_format     = optional(string)
    event_types        = optional(list(string))
    custom_attributes  = optional(map(string))
    object_name_prefix = optional(string)
  }))
  default = {}
}

# Timeouts
variable "timeouts" {
  description = "Timeouts for bucket operations"
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default = {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

# Module Dependencies
variable "module_depends_on" {
  description = "List of modules or resources this module depends on"
  type        = list(any)
  default     = []
}