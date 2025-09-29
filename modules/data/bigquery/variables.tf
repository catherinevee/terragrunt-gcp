# BigQuery Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "dataset_id" {
  description = "The ID of the BigQuery dataset"
  type        = string
}

variable "location" {
  description = "The location for the BigQuery dataset"
  type        = string
  default     = "US"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Dataset Configuration
variable "friendly_name" {
  description = "A user-friendly name for the dataset"
  type        = string
  default     = null
}

variable "description" {
  description = "A user-friendly description of the dataset"
  type        = string
  default     = null
}

variable "default_table_expiration_ms" {
  description = "Default expiration for tables in milliseconds"
  type        = number
  default     = null
}

variable "default_partition_expiration_ms" {
  description = "Default partition expiration in milliseconds"
  type        = number
  default     = null
}

variable "default_collation" {
  description = "Default collation for the dataset"
  type        = string
  default     = null
}

variable "max_time_travel_hours" {
  description = "Max time travel in hours (168 to 168 hours)"
  type        = number
  default     = null

  validation {
    condition     = var.max_time_travel_hours == null || (var.max_time_travel_hours >= 48 && var.max_time_travel_hours <= 168)
    error_message = "max_time_travel_hours must be between 48 and 168"
  }
}

variable "storage_billing_model" {
  description = "Storage billing model (LOGICAL or PHYSICAL)"
  type        = string
  default     = null

  validation {
    condition     = var.storage_billing_model == null || contains(["LOGICAL", "PHYSICAL"], var.storage_billing_model)
    error_message = "storage_billing_model must be LOGICAL or PHYSICAL"
  }
}

variable "delete_contents_on_destroy" {
  description = "If true, delete all tables in the dataset when destroying"
  type        = bool
  default     = false
}

# Encryption
variable "kms_key_name" {
  description = "Default KMS key name for the dataset"
  type        = string
  default     = null
}

# Access Control
variable "access" {
  description = "Access control rules for the dataset"
  type = list(object({
    role           = optional(string)
    user_by_email  = optional(string)
    group_by_email = optional(string)
    domain         = optional(string)
    special_group  = optional(string)
    iam_member     = optional(string)
    view = optional(object({
      dataset_id = string
      project_id = string
      table_id   = string
    }))
    dataset = optional(object({
      dataset = object({
        dataset_id = string
        project_id = string
      })
      target_types = list(string)
    }))
    routine = optional(object({
      dataset_id = string
      project_id = string
      routine_id = string
    }))
  }))
  default = []
}

variable "enable_default_access" {
  description = "Enable default access for Terraform service account"
  type        = bool
  default     = false
}

# External Dataset Reference
variable "external_dataset_reference" {
  description = "External dataset reference configuration"
  type = object({
    external_source = string
    connection      = string
  })
  default = null
}

# Labels
variable "dataset_labels" {
  description = "Labels for the dataset"
  type        = map(string)
  default     = {}
}

variable "table_labels" {
  description = "Default labels for tables"
  type        = map(string)
  default     = {}
}

# Tables
variable "tables" {
  description = "Map of tables to create in the dataset"
  type = map(object({
    friendly_name            = optional(string)
    description              = optional(string)
    schema                   = optional(string)
    deletion_protection      = optional(bool)
    expiration_time          = optional(number)
    max_staleness            = optional(string)
    require_partition_filter = optional(bool)
    labels                   = optional(map(string))

    external_data_configuration = optional(object({
      source_uris               = list(string)
      source_format             = string
      autodetect                = optional(bool)
      compression               = optional(string)
      ignore_unknown_values     = optional(bool)
      max_bad_records           = optional(number)
      schema                    = optional(string)
      reference_file_schema_uri = optional(string)

      csv_options = optional(object({
        quote                 = optional(string)
        allow_jagged_rows     = optional(bool)
        allow_quoted_newlines = optional(bool)
        encoding              = optional(string)
        field_delimiter       = optional(string)
        skip_leading_rows     = optional(number)
      }))

      google_sheets_options = optional(object({
        range             = optional(string)
        skip_leading_rows = optional(number)
      }))

      hive_partitioning_options = optional(object({
        mode                     = optional(string)
        require_partition_filter = optional(bool)
        source_uri_prefix        = optional(string)
      }))

      avro_options = optional(object({
        use_avro_logical_types = optional(bool)
      }))

      json_options = optional(object({
        encoding = optional(string)
      }))

      parquet_options = optional(object({
        enum_as_string        = optional(bool)
        enable_list_inference = optional(bool)
      }))
    }))

    time_partitioning = optional(object({
      type                     = string
      field                    = optional(string)
      expiration_ms            = optional(number)
      require_partition_filter = optional(bool)
    }))

    range_partitioning = optional(object({
      field = string
      range = object({
        start    = number
        end      = number
        interval = number
      })
    }))

    clustering = optional(list(string))

    materialized_view = optional(object({
      query                            = string
      enable_refresh                   = optional(bool)
      refresh_interval_ms              = optional(number)
      allow_non_incremental_definition = optional(bool)
    }))

    view = optional(object({
      query          = string
      use_legacy_sql = optional(bool)
    }))

    table_constraints = optional(object({
      primary_key = optional(object({
        columns = list(string)
      }))
      foreign_keys = optional(list(object({
        name = string
        referenced_table = object({
          project_id = string
          dataset_id = string
          table_id   = string
        })
        column_references = object({
          referencing_column = string
          referenced_column  = string
        })
      })))
    }))

    kms_key_name = optional(string)
  }))
  default = {}
}

variable "table_deletion_protection" {
  description = "Default deletion protection for tables"
  type        = bool
  default     = false
}

# Routines
variable "routines" {
  description = "Map of routines (functions/procedures) to create"
  type = map(object({
    routine_type      = string
    language          = string
    definition_body   = string
    description       = optional(string)
    determinism_level = optional(string)

    arguments = optional(list(object({
      name          = string
      argument_kind = optional(string)
      mode          = optional(string)
      data_type     = optional(string)
    })))

    return_type        = optional(string)
    return_table_type  = optional(string)
    imported_libraries = optional(list(string))

    remote_function_options = optional(object({
      endpoint             = string
      connection           = string
      user_defined_context = optional(map(string))
      max_batching_rows    = optional(number)
    }))

    spark_options = optional(object({
      connection      = string
      runtime_version = string
      container_image = optional(string)
      properties      = optional(map(string))
      main_file_uri   = optional(string)
      main_class      = optional(string)
      py_file_uris    = optional(list(string))
      jar_uris        = optional(list(string))
      file_uris       = optional(list(string))
      archive_uris    = optional(list(string))
    }))
  }))
  default = {}
}

# IAM
variable "dataset_iam_policy" {
  description = "IAM policy document for the dataset"
  type        = string
  default     = null
}

variable "dataset_iam_bindings" {
  description = "IAM role bindings for the dataset"
  type        = map(list(string))
  default     = {}
}

variable "dataset_iam_binding_conditions" {
  description = "Conditions for dataset IAM bindings"
  type = map(object({
    title       = string
    description = optional(string)
    expression  = string
  }))
  default = {}
}

variable "dataset_iam_members" {
  description = "Individual IAM member bindings for the dataset"
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

variable "table_iam_members" {
  description = "Individual IAM member bindings for tables"
  type = map(object({
    table_id = string
    role     = string
    member   = string
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  default = {}
}

# Data Transfer
variable "data_transfers" {
  description = "Data transfer configurations"
  type = map(object({
    data_source_id = string
    display_name   = string
    schedule       = optional(string)
    schedule_options = optional(object({
      start_time              = optional(string)
      end_time                = optional(string)
      disable_auto_scheduling = optional(bool)
    }))
    params                    = optional(map(string))
    data_refresh_window_days  = optional(number)
    disabled                  = optional(bool)
    notification_pubsub_topic = optional(string)
    email_preferences = optional(object({
      enable_failure_email = optional(bool)
    }))
    service_account_name = optional(string)
  }))
  default = {}
}

# Reservation
variable "create_reservation" {
  description = "Create a BigQuery reservation"
  type        = bool
  default     = false
}

variable "reservation_name" {
  description = "Name of the reservation"
  type        = string
  default     = null
}

variable "reservation_slot_capacity" {
  description = "Slot capacity for the reservation"
  type        = number
  default     = 100
}

variable "reservation_edition" {
  description = "Edition of the reservation"
  type        = string
  default     = "STANDARD"
}

variable "reservation_ignore_idle_slots" {
  description = "If true, idle slots will be ignored"
  type        = bool
  default     = false
}

variable "reservation_concurrency" {
  description = "Maximum number of concurrent queries"
  type        = number
  default     = null
}

variable "reservation_multi_region_auxiliary" {
  description = "Is this a multi-region auxiliary reservation"
  type        = bool
  default     = false
}

variable "reservation_autoscale" {
  description = "Autoscale configuration for reservation"
  type = object({
    current_slots = optional(number)
    max_slots     = number
  })
  default = null
}

# Capacity Commitment
variable "create_capacity_commitment" {
  description = "Create a capacity commitment"
  type        = bool
  default     = false
}

variable "commitment_plan" {
  description = "Commitment plan (FLEX, MONTHLY, ANNUAL)"
  type        = string
  default     = "FLEX"
}

variable "commitment_slot_count" {
  description = "Number of slots for the commitment"
  type        = number
  default     = 100
}

variable "commitment_edition" {
  description = "Edition for the commitment"
  type        = string
  default     = "STANDARD"
}

variable "commitment_renewal_plan" {
  description = "Renewal plan for the commitment"
  type        = string
  default     = "FLEX"
}

# Reservation Assignment
variable "reservation_assignment_config" {
  description = "Configuration for reservation assignment"
  type = object({
    assignee = string
    job_type = optional(string)
    priority = optional(number)
  })
  default = null
}

# Lifecycle Management
variable "ignore_changes_on_dataset" {
  description = "List of dataset attributes to ignore changes on"
  type        = list(string)
  default     = []
}

variable "ignore_changes_on_tables" {
  description = "List of table attributes to ignore changes on"
  type        = list(string)
  default     = []
}