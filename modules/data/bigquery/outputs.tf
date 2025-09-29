# BigQuery Module Outputs

# Dataset Information
output "dataset_id" {
  description = "The ID of the BigQuery dataset"
  value       = google_bigquery_dataset.dataset.dataset_id
}

output "dataset_self_link" {
  description = "The self link of the dataset"
  value       = google_bigquery_dataset.dataset.self_link
}

output "dataset_friendly_name" {
  description = "The friendly name of the dataset"
  value       = google_bigquery_dataset.dataset.friendly_name
}

output "dataset_description" {
  description = "The description of the dataset"
  value       = google_bigquery_dataset.dataset.description
}

output "dataset_location" {
  description = "The location of the dataset"
  value       = google_bigquery_dataset.dataset.location
}

output "dataset_creation_time" {
  description = "The creation time of the dataset"
  value       = google_bigquery_dataset.dataset.creation_time
}

output "dataset_last_modified_time" {
  description = "The last modification time of the dataset"
  value       = google_bigquery_dataset.dataset.last_modified_time
}

output "dataset_etag" {
  description = "The etag of the dataset"
  value       = google_bigquery_dataset.dataset.etag
}

output "dataset_labels" {
  description = "The labels attached to the dataset"
  value       = google_bigquery_dataset.dataset.labels
}

# Dataset Configuration
output "default_table_expiration_ms" {
  description = "Default table expiration in milliseconds"
  value       = google_bigquery_dataset.dataset.default_table_expiration_ms
}

output "default_partition_expiration_ms" {
  description = "Default partition expiration in milliseconds"
  value       = google_bigquery_dataset.dataset.default_partition_expiration_ms
}

output "default_collation" {
  description = "Default collation for the dataset"
  value       = google_bigquery_dataset.dataset.default_collation
}

output "max_time_travel_hours" {
  description = "Maximum time travel in hours"
  value       = google_bigquery_dataset.dataset.max_time_travel_hours
}

output "storage_billing_model" {
  description = "Storage billing model"
  value       = google_bigquery_dataset.dataset.storage_billing_model
}

# Encryption
output "default_encryption_configuration" {
  description = "Default encryption configuration for the dataset"
  value       = google_bigquery_dataset.dataset.default_encryption_configuration
}

output "kms_key_name" {
  description = "KMS key name used for encryption"
  value       = try(google_bigquery_dataset.dataset.default_encryption_configuration[0].kms_key_name, null)
}

# Access Control
output "access" {
  description = "Access control rules for the dataset"
  value       = google_bigquery_dataset.dataset.access
}

# Tables
output "tables" {
  description = "Information about all tables in the dataset"
  value = {
    for table_id, table in google_bigquery_table.tables : table_id => {
      id                    = table.id
      self_link            = table.self_link
      table_id             = table.table_id
      friendly_name        = table.friendly_name
      description          = table.description
      type                 = table.type
      creation_time        = table.creation_time
      expiration_time      = table.expiration_time
      last_modified_time   = table.last_modified_time
      location             = table.location
      num_bytes            = table.num_bytes
      num_long_term_bytes  = table.num_long_term_bytes
      num_rows             = table.num_rows
      labels               = table.labels
      etag                 = table.etag

      schema = table.schema

      time_partitioning = try({
        type                     = table.time_partitioning[0].type
        field                    = table.time_partitioning[0].field
        expiration_ms            = table.time_partitioning[0].expiration_ms
        require_partition_filter = table.time_partitioning[0].require_partition_filter
      }, null)

      range_partitioning = try({
        field = table.range_partitioning[0].field
        range = {
          start    = table.range_partitioning[0].range[0].start
          end      = table.range_partitioning[0].range[0].end
          interval = table.range_partitioning[0].range[0].interval
        }
      }, null)

      clustering            = table.clustering
      encryption_configuration = table.encryption_configuration

      view = try({
        query          = table.view[0].query
        use_legacy_sql = table.view[0].use_legacy_sql
      }, null)

      materialized_view = try({
        query                            = table.materialized_view[0].query
        enable_refresh                   = table.materialized_view[0].enable_refresh
        refresh_interval_ms              = table.materialized_view[0].refresh_interval_ms
        last_refresh_time               = table.materialized_view[0].last_refresh_time
        allow_non_incremental_definition = table.materialized_view[0].allow_non_incremental_definition
      }, null)

      external_data_configuration = try({
        source_uris        = table.external_data_configuration[0].source_uris
        source_format      = table.external_data_configuration[0].source_format
        autodetect         = table.external_data_configuration[0].autodetect
        compression        = table.external_data_configuration[0].compression
        ignore_unknown_values = table.external_data_configuration[0].ignore_unknown_values
        max_bad_records    = table.external_data_configuration[0].max_bad_records
        schema             = table.external_data_configuration[0].schema
        reference_file_schema_uri = table.external_data_configuration[0].reference_file_schema_uri
      }, null)
    }
  }
}

output "table_ids" {
  description = "List of all table IDs"
  value       = [for table_id, table in google_bigquery_table.tables : table.table_id]
}

output "table_self_links" {
  description = "Map of table IDs to self links"
  value       = {for table_id, table in google_bigquery_table.tables : table_id => table.self_link}
}

output "view_definitions" {
  description = "Map of view definitions"
  value = {
    for table_id, table in google_bigquery_table.tables :
    table_id => try(table.view[0].query, null)
    if try(table.view[0], null) != null
  }
}

output "materialized_view_definitions" {
  description = "Map of materialized view definitions"
  value = {
    for table_id, table in google_bigquery_table.tables :
    table_id => try(table.materialized_view[0].query, null)
    if try(table.materialized_view[0], null) != null
  }
}

# Routines
output "routines" {
  description = "Information about all routines in the dataset"
  value = {
    for routine_id, routine in google_bigquery_routine.routines : routine_id => {
      id                  = routine.id
      routine_id          = routine.routine_id
      routine_type        = routine.routine_type
      language           = routine.language
      definition_body    = routine.definition_body
      description        = routine.description
      determinism_level  = routine.determinism_level
      arguments          = routine.arguments
      return_type        = routine.return_type
      return_table_type  = routine.return_table_type
      imported_libraries = routine.imported_libraries
      creation_time      = routine.creation_time
      last_modified_time = routine.last_modified_time

      remote_function_options = try({
        endpoint                = routine.remote_function_options[0].endpoint
        connection              = routine.remote_function_options[0].connection
        user_defined_context    = routine.remote_function_options[0].user_defined_context
        max_batching_rows       = routine.remote_function_options[0].max_batching_rows
      }, null)

      spark_options = try({
        connection      = routine.spark_options[0].connection
        runtime_version = routine.spark_options[0].runtime_version
        container_image = routine.spark_options[0].container_image
        properties      = routine.spark_options[0].properties
        main_file_uri   = routine.spark_options[0].main_file_uri
        main_class      = routine.spark_options[0].main_class
        py_file_uris    = routine.spark_options[0].py_file_uris
        jar_uris        = routine.spark_options[0].jar_uris
        file_uris       = routine.spark_options[0].file_uris
        archive_uris    = routine.spark_options[0].archive_uris
      }, null)
    }
  }
}

output "routine_ids" {
  description = "List of all routine IDs"
  value       = [for routine_id, routine in google_bigquery_routine.routines : routine.routine_id]
}

# Data Transfer
output "data_transfers" {
  description = "Information about data transfer configurations"
  value = {
    for transfer_name, transfer in google_bigquery_data_transfer_config.transfers : transfer_name => {
      name                      = transfer.name
      display_name              = transfer.display_name
      data_source_id            = transfer.data_source_id
      destination_dataset_id    = transfer.destination_dataset_id
      schedule                  = transfer.schedule
      schedule_options          = transfer.schedule_options
      params                    = transfer.params
      data_refresh_window_days  = transfer.data_refresh_window_days
      disabled                  = transfer.disabled
      notification_pubsub_topic = transfer.notification_pubsub_topic
      email_preferences         = transfer.email_preferences
      service_account_name      = transfer.service_account_name
      state                     = transfer.state
      user_id                   = transfer.user_id
      dataset_region            = transfer.dataset_region
      next_run_time            = transfer.next_run_time
    }
  }
}

output "data_transfer_names" {
  description = "Names of all data transfer configurations"
  value       = [for transfer_name, transfer in google_bigquery_data_transfer_config.transfers : transfer.name]
}

# Reservation
output "reservation" {
  description = "Reservation information"
  value = try({
    id                         = google_bigquery_reservation.reservation[0].id
    name                       = google_bigquery_reservation.reservation[0].name
    slot_capacity              = google_bigquery_reservation.reservation[0].slot_capacity
    edition                    = google_bigquery_reservation.reservation[0].edition
    ignore_idle_slots          = google_bigquery_reservation.reservation[0].ignore_idle_slots
    concurrency                = google_bigquery_reservation.reservation[0].concurrency
    multi_region_auxiliary     = google_bigquery_reservation.reservation[0].multi_region_auxiliary
    creation_time              = google_bigquery_reservation.reservation[0].creation_time
    update_time                = google_bigquery_reservation.reservation[0].update_time
    autoscale                  = google_bigquery_reservation.reservation[0].autoscale
  }, null)
}

output "reservation_name" {
  description = "Name of the reservation"
  value       = try(google_bigquery_reservation.reservation[0].name, null)
}

# Capacity Commitment
output "capacity_commitment" {
  description = "Capacity commitment information"
  value = try({
    id                = google_bigquery_capacity_commitment.commitment[0].id
    commitment_plan   = google_bigquery_capacity_commitment.commitment[0].commitment_plan
    slot_count        = google_bigquery_capacity_commitment.commitment[0].slot_count
    edition           = google_bigquery_capacity_commitment.commitment[0].edition
    renewal_plan      = google_bigquery_capacity_commitment.commitment[0].renewal_plan
    state            = google_bigquery_capacity_commitment.commitment[0].state
    commitment_start_time = google_bigquery_capacity_commitment.commitment[0].commitment_start_time
    commitment_end_time   = google_bigquery_capacity_commitment.commitment[0].commitment_end_time
  }, null)
}

output "capacity_commitment_id" {
  description = "ID of the capacity commitment"
  value       = try(google_bigquery_capacity_commitment.commitment[0].id, null)
}

# Reservation Assignment
output "reservation_assignment" {
  description = "Reservation assignment information"
  value = try({
    id          = google_bigquery_reservation_assignment.assignment[0].id
    name        = google_bigquery_reservation_assignment.assignment[0].name
    reservation = google_bigquery_reservation_assignment.assignment[0].reservation
    assignee    = google_bigquery_reservation_assignment.assignment[0].assignee
    job_type    = google_bigquery_reservation_assignment.assignment[0].job_type
    priority    = google_bigquery_reservation_assignment.assignment[0].priority
    state       = google_bigquery_reservation_assignment.assignment[0].state
  }, null)
}

# IAM
output "dataset_iam_policy_etag" {
  description = "Etag of the dataset IAM policy"
  value       = try(google_bigquery_dataset_iam_policy.dataset_policy[0].etag, null)
}

output "dataset_iam_bindings" {
  description = "Map of dataset IAM bindings"
  value = {
    for role, binding in google_bigquery_dataset_iam_binding.dataset_bindings : role => {
      role      = binding.role
      members   = binding.members
      condition = binding.condition
    }
  }
}

output "dataset_iam_members" {
  description = "Map of individual dataset IAM members"
  value = {
    for key, member in google_bigquery_dataset_iam_member.dataset_members : key => {
      role      = member.role
      member    = member.member
      condition = member.condition
    }
  }
}

output "table_iam_members" {
  description = "Map of table IAM members"
  value = {
    for key, member in google_bigquery_table_iam_member.table_members : key => {
      table_id  = member.table_id
      role      = member.role
      member    = member.member
      condition = member.condition
    }
  }
}

# Console and Command Links
output "console_url" {
  description = "Google Cloud Console URL for the dataset"
  value       = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.dataset.dataset_id}"
}

output "bq_commands" {
  description = "Useful bq CLI commands for the dataset"
  value = {
    show_dataset = "bq show --format=prettyjson ${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}"

    list_tables = "bq ls --format=prettyjson ${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}"

    query_dataset = "bq query --use_legacy_sql=false 'SELECT * FROM `${var.project_id}.${google_bigquery_dataset.dataset.dataset_id}.TABLE_NAME` LIMIT 10'"

    create_table = "bq mk --table ${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}.new_table schema.json"

    load_data = "bq load --source_format=CSV ${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}.table_name gs://bucket/file.csv"

    export_data = "bq extract --destination_format=CSV ${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}.table_name gs://bucket/export.csv"

    update_description = "bq update --description 'New description' ${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}"

    update_labels = "bq update --set_label key:value ${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}"
  }
}

# SQL Queries
output "sql_queries" {
  description = "Example SQL queries for the dataset"
  value = {
    information_schema_tables = "SELECT * FROM `${var.project_id}.${google_bigquery_dataset.dataset.dataset_id}.INFORMATION_SCHEMA.TABLES`"

    information_schema_columns = "SELECT * FROM `${var.project_id}.${google_bigquery_dataset.dataset.dataset_id}.INFORMATION_SCHEMA.COLUMNS`"

    information_schema_views = "SELECT * FROM `${var.project_id}.${google_bigquery_dataset.dataset.dataset_id}.INFORMATION_SCHEMA.VIEWS`"

    information_schema_routines = "SELECT * FROM `${var.project_id}.${google_bigquery_dataset.dataset.dataset_id}.INFORMATION_SCHEMA.ROUTINES`"

    storage_billing = "SELECT SUM(size_bytes)/POW(10,9) as size_gb FROM `${var.project_id}.${google_bigquery_dataset.dataset.dataset_id}.__TABLES__`"

    table_metadata = "SELECT * FROM `${var.project_id}.${google_bigquery_dataset.dataset.dataset_id}.__TABLES__`"
  }
}

# Import Commands
output "import_commands" {
  description = "Terraform import commands for the resources"
  value = {
    dataset = "terraform import google_bigquery_dataset.dataset projects/${var.project_id}/datasets/${google_bigquery_dataset.dataset.dataset_id}"

    table = length(google_bigquery_table.tables) > 0 ?
      "terraform import 'google_bigquery_table.tables[\\\"TABLE_ID\\\"]' projects/${var.project_id}/datasets/${google_bigquery_dataset.dataset.dataset_id}/tables/TABLE_ID" :
      null

    routine = length(google_bigquery_routine.routines) > 0 ?
      "terraform import 'google_bigquery_routine.routines[\\\"ROUTINE_ID\\\"]' projects/${var.project_id}/datasets/${google_bigquery_dataset.dataset.dataset_id}/routines/ROUTINE_ID" :
      null
  }
}