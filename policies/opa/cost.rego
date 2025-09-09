package terraform.cost

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Cost thresholds by environment
cost_limits := {
    "dev": 5000,
    "staging": 10000,
    "prod": 50000,
    "production": 50000
}

# Deny expensive instance types in non-production
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    machine_type := resource.change.after.machine_type
    environment := resource.change.after.labels.environment
    environment in ["dev", "staging"]
    expensive_types := ["n2-", "n2d-", "c2-", "c2d-", "m1-", "m2-", "a2-"]
    type_prefix := expensive_types[_]
    contains(machine_type, type_prefix)
    msg := sprintf("Instance %s uses expensive machine type %s in %s environment. Use E2 or N1 instances instead.", [resource.address, machine_type, environment])
}

# Require preemptible instances for batch workloads
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    labels := resource.change.after.labels
    labels.workload_type == "batch"
    scheduling := resource.change.after.scheduling[_]
    not scheduling.preemptible
    msg := sprintf("Batch workload instance %s must use preemptible instances for cost optimization.", [resource.address])
}

# Limit GKE cluster size in non-production
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_container_node_pool"
    environment := resource.change.after.labels.environment
    environment in ["dev", "staging"]
    autoscaling := resource.change.after.autoscaling[_]
    autoscaling.max_node_count > 10
    msg := sprintf("GKE node pool %s in %s cannot have more than 10 nodes. Current max: %d", [resource.address, environment, autoscaling.max_node_count])
}

# Require autoscaling for production GKE
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_container_node_pool"
    environment := resource.change.after.labels.environment
    environment in ["prod", "production"]
    not resource.change.after.autoscaling
    msg := sprintf("Production GKE node pool %s must have autoscaling enabled for cost efficiency.", [resource.address])
}

# Enforce storage lifecycle policies
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    environment := resource.change.after.labels.environment
    environment != "dev"
    not resource.change.after.lifecycle_rule
    msg := sprintf("Storage bucket %s must have lifecycle rules for automatic data archival and deletion.", [resource.address])
}

# Limit Cloud SQL instance sizes in dev
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    environment := resource.change.after.labels.environment
    environment == "dev"
    settings := resource.change.after.settings[_]
    tier := settings.tier
    expensive_tiers := ["db-n1-highmem", "db-n1-standard-8", "db-n1-standard-16", "db-n1-standard-32"]
    tier in expensive_tiers
    msg := sprintf("Dev environment database %s cannot use expensive tier %s. Use db-f1-micro or db-g1-small.", [resource.address, tier])
}

# Require committed use discounts for production
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    environment := resource.change.after.labels.environment
    environment in ["prod", "production"]
    not resource.change.after.reservation_affinity
    msg := sprintf("Production instance %s should use committed use discounts for cost savings.", [resource.address])
}

# Warn about multi-regional storage in non-production
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    environment := resource.change.after.labels.environment
    environment in ["dev", "staging"]
    location := resource.change.after.location
    location in ["US", "EU", "ASIA"]
    msg := sprintf("Non-production bucket %s uses multi-regional storage (%s). Consider using regional storage for cost savings.", [resource.address, location])
}

# Enforce regional load balancers for internal traffic
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_global_forwarding_rule"
    labels := resource.change.after.labels
    labels.traffic_type == "internal"
    msg := sprintf("Internal traffic should use regional load balancer instead of global: %s", [resource.address])
}

# Limit static IP allocations
deny[msg] {
    count([r | r := input.resource_changes[_]; r.type == "google_compute_address"; r.change.actions[_] == "create"]) > 5
    msg := "Cannot allocate more than 5 static IPs in a single deployment. Use dynamic IPs where possible."
}

# Require cost estimation tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type in [
        "google_compute_instance",
        "google_container_cluster",
        "google_sql_database_instance",
        "google_storage_bucket"
    ]
    labels := resource.change.after.labels
    not labels.cost_center
    msg := sprintf("Resource %s must have 'cost_center' label for cost allocation.", [resource.address])
}

# Enforce snapshot retention limits
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_snapshot"
    labels := resource.change.after.labels
    environment := labels.environment
    snapshot_count := count([s | s := input.resource_changes[_]; s.type == "google_compute_snapshot"])
    environment == "dev"
    snapshot_count > 7
    msg := sprintf("Dev environment cannot have more than 7 snapshots. Current: %d", [snapshot_count])
}

# Warn about underutilized reserved capacity
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_reservation"
    specific_reservation := resource.change.after.specific_reservation[_]
    count := specific_reservation.count
    count > 10
    msg := sprintf("Large reservation %s (%d instances). Ensure utilization is monitored.", [resource.address, count])
}

# Enforce budget alerts
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_billing_budget"
    threshold_rules := resource.change.after.threshold_rules
    count(threshold_rules) < 3
    msg := sprintf("Budget %s must have at least 3 threshold alerts (e.g., 50%%, 80%%, 100%%).", [resource.address])
}

# Limit BigQuery slot commitments
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_bigquery_reservation"
    environment := resource.change.after.labels.environment
    environment in ["dev", "staging"]
    slot_capacity := resource.change.after.slot_capacity
    slot_capacity > 500
    msg := sprintf("Non-production BigQuery reservation %s cannot exceed 500 slots. Current: %d", [resource.address, slot_capacity])
}