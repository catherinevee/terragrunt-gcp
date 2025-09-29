# BigQuery Dataset and Table Module
# Manages BigQuery datasets, tables, views, and routines

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

locals {
  # Dataset configuration
  dataset_id = var.dataset_id

  # Access configuration with defaults
  access_entries = concat(
    var.access,
    var.enable_default_access ? [
      {
        role          = "OWNER"
        user_by_email = "terraform@${var.project_id}.iam.gserviceaccount.com"
      }
    ] : []
  )

  # Labels with defaults
  dataset_labels = merge(
    var.dataset_labels,
    {
      managed_by  = "terraform"
      module      = "bigquery"
      environment = var.environment
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Table labels
  table_labels = merge(
    var.table_labels,
    {
      managed_by = "terraform"
      module     = "bigquery"
      dataset    = local.dataset_id
    }
  )

  # Encryption configuration
  encryption_configuration = var.kms_key_name != null ? {
    kms_key_name = var.kms_key_name
  } : null
}

# BigQuery Dataset
resource "google_bigquery_dataset" "dataset" {
  project    = var.project_id
  dataset_id = local.dataset_id
  location   = var.location

  friendly_name                   = var.friendly_name
  description                     = var.description
  default_table_expiration_ms     = var.default_table_expiration_ms
  default_partition_expiration_ms = var.default_partition_expiration_ms

  labels = local.dataset_labels

  # Encryption
  default_encryption_configuration {
    kms_key_name = var.kms_key_name
  }

  # Access control
  dynamic "access" {
    for_each = local.access_entries
    content {
      role           = lookup(access.value, "role", null)
      user_by_email  = lookup(access.value, "user_by_email", null)
      group_by_email = lookup(access.value, "group_by_email", null)
      domain         = lookup(access.value, "domain", null)
      special_group  = lookup(access.value, "special_group", null)
      iam_member     = lookup(access.value, "iam_member", null)

      dynamic "view" {
        for_each = lookup(access.value, "view", null) != null ? [access.value.view] : []
        content {
          dataset_id = view.value.dataset_id
          project_id = view.value.project_id
          table_id   = view.value.table_id
        }
      }

      dynamic "dataset" {
        for_each = lookup(access.value, "dataset", null) != null ? [access.value.dataset] : []
        content {
          dataset {
            dataset_id = dataset.value.dataset_id
            project_id = dataset.value.project_id
          }
          target_types = dataset.value.target_types
        }
      }

      dynamic "routine" {
        for_each = lookup(access.value, "routine", null) != null ? [access.value.routine] : []
        content {
          dataset_id = routine.value.dataset_id
          project_id = routine.value.project_id
          routine_id = routine.value.routine_id
        }
      }
    }
  }

  # Collation
  default_collation = var.default_collation

  # External dataset reference
  dynamic "external_dataset_reference" {
    for_each = var.external_dataset_reference != null ? [var.external_dataset_reference] : []
    content {
      external_source = external_dataset_reference.value.external_source
      connection      = external_dataset_reference.value.connection
    }
  }

  # Max time travel
  max_time_travel_hours = var.max_time_travel_hours

  # Storage billing model
  storage_billing_model = var.storage_billing_model

  # Delete contents on destroy
  delete_contents_on_destroy = var.delete_contents_on_destroy

  lifecycle {
    # ignore_changes must be static, not variable
    ignore_changes = []
  }
}

# BigQuery Tables
resource "google_bigquery_table" "tables" {
  for_each = var.tables

  project    = var.project_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = each.key

  friendly_name = lookup(each.value, "friendly_name", null)
  description   = lookup(each.value, "description", null)

  # Table type and schema
  schema = lookup(each.value, "schema", null)

  # External data configuration
  dynamic "external_data_configuration" {
    for_each = lookup(each.value, "external_data_configuration", null) != null ? [each.value.external_data_configuration] : []
    content {
      source_uris               = external_data_configuration.value.source_uris
      source_format             = external_data_configuration.value.source_format
      autodetect                = lookup(external_data_configuration.value, "autodetect", false)
      compression               = lookup(external_data_configuration.value, "compression", null)
      ignore_unknown_values     = lookup(external_data_configuration.value, "ignore_unknown_values", false)
      max_bad_records           = lookup(external_data_configuration.value, "max_bad_records", 0)
      schema                    = lookup(external_data_configuration.value, "schema", null)
      reference_file_schema_uri = lookup(external_data_configuration.value, "reference_file_schema_uri", null)

      dynamic "csv_options" {
        for_each = lookup(external_data_configuration.value, "csv_options", null) != null ? [external_data_configuration.value.csv_options] : []
        content {
          quote                 = lookup(csv_options.value, "quote", null)
          allow_jagged_rows     = lookup(csv_options.value, "allow_jagged_rows", false)
          allow_quoted_newlines = lookup(csv_options.value, "allow_quoted_newlines", false)
          encoding              = lookup(csv_options.value, "encoding", "UTF-8")
          field_delimiter       = lookup(csv_options.value, "field_delimiter", ",")
          skip_leading_rows     = lookup(csv_options.value, "skip_leading_rows", 0)
        }
      }

      dynamic "google_sheets_options" {
        for_each = lookup(external_data_configuration.value, "google_sheets_options", null) != null ? [external_data_configuration.value.google_sheets_options] : []
        content {
          range             = lookup(google_sheets_options.value, "range", null)
          skip_leading_rows = lookup(google_sheets_options.value, "skip_leading_rows", 0)
        }
      }

      dynamic "hive_partitioning_options" {
        for_each = lookup(external_data_configuration.value, "hive_partitioning_options", null) != null ? [external_data_configuration.value.hive_partitioning_options] : []
        content {
          mode                     = lookup(hive_partitioning_options.value, "mode", null)
          require_partition_filter = lookup(hive_partitioning_options.value, "require_partition_filter", false)
          source_uri_prefix        = lookup(hive_partitioning_options.value, "source_uri_prefix", null)
        }
      }

      dynamic "avro_options" {
        for_each = lookup(external_data_configuration.value, "avro_options", null) != null ? [external_data_configuration.value.avro_options] : []
        content {
          use_avro_logical_types = lookup(avro_options.value, "use_avro_logical_types", false)
        }
      }

      dynamic "json_options" {
        for_each = lookup(external_data_configuration.value, "json_options", null) != null ? [external_data_configuration.value.json_options] : []
        content {
          encoding = lookup(json_options.value, "encoding", "UTF-8")
        }
      }

      dynamic "parquet_options" {
        for_each = lookup(external_data_configuration.value, "parquet_options", null) != null ? [external_data_configuration.value.parquet_options] : []
        content {
          enum_as_string        = lookup(parquet_options.value, "enum_as_string", false)
          enable_list_inference = lookup(parquet_options.value, "enable_list_inference", false)
        }
      }
    }
  }

  # Time partitioning
  dynamic "time_partitioning" {
    for_each = lookup(each.value, "time_partitioning", null) != null ? [each.value.time_partitioning] : []
    content {
      type                     = time_partitioning.value.type
      field                    = lookup(time_partitioning.value, "field", null)
      expiration_ms            = lookup(time_partitioning.value, "expiration_ms", null)
      require_partition_filter = lookup(time_partitioning.value, "require_partition_filter", false)
    }
  }

  # Range partitioning
  dynamic "range_partitioning" {
    for_each = lookup(each.value, "range_partitioning", null) != null ? [each.value.range_partitioning] : []
    content {
      field = range_partitioning.value.field
      range {
        start    = range_partitioning.value.range.start
        end      = range_partitioning.value.range.end
        interval = range_partitioning.value.range.interval
      }
    }
  }

  # Clustering
  clustering = lookup(each.value, "clustering", null)

  # Materialized view
  dynamic "materialized_view" {
    for_each = lookup(each.value, "materialized_view", null) != null ? [each.value.materialized_view] : []
    content {
      query                            = materialized_view.value.query
      enable_refresh                   = lookup(materialized_view.value, "enable_refresh", true)
      refresh_interval_ms              = lookup(materialized_view.value, "refresh_interval_ms", null)
      allow_non_incremental_definition = lookup(materialized_view.value, "allow_non_incremental_definition", false)
    }
  }

  # View
  dynamic "view" {
    for_each = lookup(each.value, "view", null) != null ? [each.value.view] : []
    content {
      query          = view.value.query
      use_legacy_sql = lookup(view.value, "use_legacy_sql", false)
    }
  }

  # Table constraints
  dynamic "table_constraints" {
    for_each = lookup(each.value, "table_constraints", null) != null ? [each.value.table_constraints] : []
    content {
      dynamic "primary_key" {
        for_each = lookup(table_constraints.value, "primary_key", null) != null ? [table_constraints.value.primary_key] : []
        content {
          columns = primary_key.value.columns
        }
      }

      dynamic "foreign_keys" {
        for_each = lookup(table_constraints.value, "foreign_keys", [])
        content {
          name = foreign_keys.value.name
          referenced_table {
            project_id = foreign_keys.value.referenced_table.project_id
            dataset_id = foreign_keys.value.referenced_table.dataset_id
            table_id   = foreign_keys.value.referenced_table.table_id
          }
          column_references {
            referencing_column = foreign_keys.value.column_references.referencing_column
            referenced_column  = foreign_keys.value.column_references.referenced_column
          }
        }
      }
    }
  }

  # Expiration
  expiration_time = lookup(each.value, "expiration_time", null)

  # Encryption
  encryption_configuration {
    kms_key_name = lookup(each.value, "kms_key_name", var.kms_key_name)
  }

  # Labels
  labels = merge(
    local.table_labels,
    lookup(each.value, "labels", {})
  )

  # Deletion protection
  deletion_protection = lookup(each.value, "deletion_protection", var.table_deletion_protection)

  # Max staleness
  max_staleness = lookup(each.value, "max_staleness", null)

  # Require partition filter
  require_partition_filter = lookup(each.value, "require_partition_filter", false)

  lifecycle {
    # ignore_changes must be static, not variable
    ignore_changes = []
  }

  depends_on = [google_bigquery_dataset.dataset]
}

# BigQuery Routines (Functions and Procedures)
resource "google_bigquery_routine" "routines" {
  for_each = var.routines

  project    = var.project_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  routine_id = each.key

  routine_type = each.value.routine_type
  language     = each.value.language

  # Definition body
  definition_body = each.value.definition_body

  # Description
  description = lookup(each.value, "description", null)

  # Determinism level
  determinism_level = lookup(each.value, "determinism_level", null)

  # Arguments
  dynamic "arguments" {
    for_each = lookup(each.value, "arguments", [])
    content {
      name          = arguments.value.name
      argument_kind = lookup(arguments.value, "argument_kind", null)
      mode          = lookup(arguments.value, "mode", null)
      data_type     = lookup(arguments.value, "data_type", null)
    }
  }

  # Return type
  return_type = lookup(each.value, "return_type", null)

  # Return table type
  return_table_type = lookup(each.value, "return_table_type", null)

  # Imported libraries
  imported_libraries = lookup(each.value, "imported_libraries", null)

  # Remote function options
  dynamic "remote_function_options" {
    for_each = lookup(each.value, "remote_function_options", null) != null ? [each.value.remote_function_options] : []
    content {
      endpoint             = remote_function_options.value.endpoint
      connection           = remote_function_options.value.connection
      user_defined_context = lookup(remote_function_options.value, "user_defined_context", null)
      max_batching_rows    = lookup(remote_function_options.value, "max_batching_rows", null)
    }
  }

  # Spark options
  dynamic "spark_options" {
    for_each = lookup(each.value, "spark_options", null) != null ? [each.value.spark_options] : []
    content {
      connection      = spark_options.value.connection
      runtime_version = spark_options.value.runtime_version
      container_image = lookup(spark_options.value, "container_image", null)
      properties      = lookup(spark_options.value, "properties", null)
      main_file_uri   = lookup(spark_options.value, "main_file_uri", null)
      main_class      = lookup(spark_options.value, "main_class", null)
      py_file_uris    = lookup(spark_options.value, "py_file_uris", null)
      jar_uris        = lookup(spark_options.value, "jar_uris", null)
      file_uris       = lookup(spark_options.value, "file_uris", null)
      archive_uris    = lookup(spark_options.value, "archive_uris", null)
    }
  }

  depends_on = [google_bigquery_dataset.dataset]
}

# BigQuery Dataset IAM Policy
resource "google_bigquery_dataset_iam_policy" "dataset_policy" {
  count = var.dataset_iam_policy != null ? 1 : 0

  project     = var.project_id
  dataset_id  = google_bigquery_dataset.dataset.dataset_id
  policy_data = var.dataset_iam_policy
}

# BigQuery Dataset IAM Bindings
resource "google_bigquery_dataset_iam_binding" "dataset_bindings" {
  for_each = var.dataset_iam_bindings

  project    = var.project_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  role       = each.key
  members    = each.value

  dynamic "condition" {
    for_each = lookup(var.dataset_iam_binding_conditions, each.key, null) != null ? [var.dataset_iam_binding_conditions[each.key]] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# BigQuery Dataset IAM Members
resource "google_bigquery_dataset_iam_member" "dataset_members" {
  for_each = var.dataset_iam_members

  project    = var.project_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  role       = each.value.role
  member     = each.value.member

  dynamic "condition" {
    for_each = lookup(each.value, "condition", null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# BigQuery Table IAM Members
resource "google_bigquery_table_iam_member" "table_members" {
  for_each = var.table_iam_members

  project    = var.project_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = each.value.table_id
  role       = each.value.role
  member     = each.value.member

  dynamic "condition" {
    for_each = lookup(each.value, "condition", null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# BigQuery Data Transfer Configuration
resource "google_bigquery_data_transfer_config" "transfers" {
  for_each = var.data_transfers

  project                = var.project_id
  location               = var.location
  data_source_id         = each.value.data_source_id
  destination_dataset_id = google_bigquery_dataset.dataset.dataset_id
  display_name           = each.value.display_name

  # Schedule
  schedule = lookup(each.value, "schedule", null)

  # Schedule options
  dynamic "schedule_options" {
    for_each = lookup(each.value, "schedule_options", null) != null ? [each.value.schedule_options] : []
    content {
      start_time              = lookup(schedule_options.value, "start_time", null)
      end_time                = lookup(schedule_options.value, "end_time", null)
      disable_auto_scheduling = lookup(schedule_options.value, "disable_auto_scheduling", false)
    }
  }

  # Parameters
  params = lookup(each.value, "params", {})

  # Data refresh window days
  data_refresh_window_days = lookup(each.value, "data_refresh_window_days", null)

  # Disabled
  disabled = lookup(each.value, "disabled", false)

  # Notification pubsub topic
  notification_pubsub_topic = lookup(each.value, "notification_pubsub_topic", null)

  # Email preferences
  dynamic "email_preferences" {
    for_each = lookup(each.value, "email_preferences", null) != null ? [each.value.email_preferences] : []
    content {
      enable_failure_email = lookup(email_preferences.value, "enable_failure_email", false)
    }
  }

  # Service account
  service_account_name = lookup(each.value, "service_account_name", null)

  depends_on = [google_bigquery_dataset.dataset]
}

# BigQuery Reservation
resource "google_bigquery_reservation" "reservation" {
  count = var.create_reservation ? 1 : 0

  project  = var.project_id
  location = var.location
  name     = var.reservation_name

  # Slot capacity
  slot_capacity = var.reservation_slot_capacity

  # Edition
  edition = var.reservation_edition

  # Ignore idle slots
  ignore_idle_slots = var.reservation_ignore_idle_slots

  # Max concurrency
  concurrency = var.reservation_concurrency

  # Multi-region auxiliary
  multi_region_auxiliary = var.reservation_multi_region_auxiliary

  # Autoscale
  dynamic "autoscale" {
    for_each = var.reservation_autoscale != null ? [var.reservation_autoscale] : []
    content {
      current_slots = lookup(autoscale.value, "current_slots", null)
      max_slots     = autoscale.value.max_slots
    }
  }
}

# BigQuery Capacity Commitment
resource "google_bigquery_capacity_commitment" "commitment" {
  count = var.create_capacity_commitment ? 1 : 0

  project  = var.project_id
  location = var.location

  # Commitment plan
  commitment_plan = var.commitment_plan

  # Slot count
  slot_count = var.commitment_slot_count

  # Edition
  edition = var.commitment_edition

  # Renewal plan
  renewal_plan = var.commitment_renewal_plan
}

# BigQuery Reservation Assignment
resource "google_bigquery_reservation_assignment" "assignment" {
  count = var.create_reservation && var.reservation_assignment_config != null ? 1 : 0

  project     = var.project_id
  location    = var.location
  reservation = google_bigquery_reservation.reservation[0].name

  # Assignee
  assignee = var.reservation_assignment_config.assignee

  # Job type
  job_type = lookup(var.reservation_assignment_config, "job_type", "QUERY")

  # Priority
  priority = lookup(var.reservation_assignment_config, "priority", null)
}