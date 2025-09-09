package terraform.security

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Deny service accounts with Owner or Editor roles
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_project_iam_member"
    role := resource.change.after.role
    role in ["roles/owner", "roles/editor"]
    msg := sprintf("Service account cannot have %s role. Use least privilege principle.", [role])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_project_iam_binding"
    role := resource.change.after.role
    role in ["roles/owner", "roles/editor"]
    msg := sprintf("IAM binding cannot use %s role. Use custom roles or predefined roles with minimal permissions.", [role])
}

# Deny public access to storage buckets
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket_iam_member"
    member := resource.change.after.member
    member in ["allUsers", "allAuthenticatedUsers"]
    msg := sprintf("Storage bucket %s cannot have public access. Member %s is not allowed.", [resource.address, member])
}

# Require encryption for storage buckets
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    encryption := resource.change.after.encryption
    not encryption[_].default_kms_key_name
    msg := sprintf("Storage bucket %s must use customer-managed encryption keys (CMEK).", [resource.address])
}

# Deny default service accounts
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_service_account"
    account_id := resource.change.after.account_id
    contains(account_id, "default")
    msg := sprintf("Default service account names are not allowed: %s. Use descriptive, purpose-specific names.", [account_id])
}

# Require SSL for Cloud SQL
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    settings := resource.change.after.settings[_]
    ip_configuration := settings.ip_configuration[_]
    not ip_configuration.require_ssl
    msg := sprintf("Cloud SQL instance %s must require SSL connections.", [resource.address])
}

# Deny public IPs for Cloud SQL
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    settings := resource.change.after.settings[_]
    ip_configuration := settings.ip_configuration[_]
    ip_configuration.ipv4_enabled
    not ip_configuration.private_network
    msg := sprintf("Cloud SQL instance %s cannot have public IP without private network configuration.", [resource.address])
}

# Require VPC flow logs
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_subnetwork"
    not resource.change.after.log_config
    msg := sprintf("Subnet %s must have VPC flow logs enabled for security monitoring.", [resource.address])
}

# Deny weak firewall rules
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_firewall"
    rule := resource.change.after
    "0.0.0.0/0" in rule.source_ranges
    rule.direction == "INGRESS"
    not rule.name contains "lb-health-check"
    msg := sprintf("Firewall rule %s has overly permissive source range (0.0.0.0/0). Restrict to specific IP ranges.", [resource.address])
}

# Require labels for resource tracking
deny[msg] {
    resource := input.resource_changes[_]
    resource.type in [
        "google_compute_instance",
        "google_container_cluster",
        "google_storage_bucket",
        "google_sql_database_instance"
    ]
    labels := resource.change.after.labels
    required_labels := ["environment", "team", "managed_by"]
    missing := [label | label := required_labels[_]; not labels[label]]
    count(missing) > 0
    msg := sprintf("Resource %s missing required labels: %v", [resource.address, missing])
}

# Enforce private GKE clusters
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_container_cluster"
    private_cluster_config := resource.change.after.private_cluster_config
    not private_cluster_config[_].enable_private_nodes
    msg := sprintf("GKE cluster %s must be private (enable_private_nodes = true).", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_container_cluster"
    private_cluster_config := resource.change.after.private_cluster_config
    not private_cluster_config[_].enable_private_endpoint
    msg := sprintf("GKE cluster %s must have private endpoint enabled for production security.", [resource.address])
}

# Require Workload Identity for GKE
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_container_cluster"
    workload_identity_config := resource.change.after.workload_identity_config
    not workload_identity_config[_].workload_pool
    msg := sprintf("GKE cluster %s must use Workload Identity for secure pod authentication.", [resource.address])
}

# Enforce deletion protection for databases
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    not resource.change.after.deletion_protection
    environment := resource.change.after.labels.environment
    environment in ["staging", "prod", "production"]
    msg := sprintf("Database %s in %s environment must have deletion protection enabled.", [resource.address, environment])
}

# Require backup configuration for production databases
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    environment := resource.change.after.labels.environment
    environment in ["prod", "production"]
    settings := resource.change.after.settings[_]
    backup_configuration := settings.backup_configuration[_]
    not backup_configuration.enabled
    msg := sprintf("Production database %s must have automated backups enabled.", [resource.address])
}

# Enforce KMS key rotation
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_kms_crypto_key"
    rotation_period := resource.change.after.rotation_period
    not rotation_period
    msg := sprintf("KMS key %s must have automatic rotation enabled.", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_kms_crypto_key"
    rotation_period := resource.change.after.rotation_period
    rotation_seconds := parse_duration(rotation_period)
    rotation_seconds > 7776000  # 90 days in seconds
    msg := sprintf("KMS key %s rotation period must be 90 days or less. Current: %s", [resource.address, rotation_period])
}

# Helper function to parse duration strings
parse_duration(duration) = seconds {
    endswith(duration, "s")
    seconds := to_number(trim_suffix(duration, "s"))
}

# Warnings for best practices (non-blocking)
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    not resource.change.after.shielded_instance_config
    msg := sprintf("Instance %s should use Shielded VM for enhanced security.", [resource.address])
}

warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    not resource.change.after.versioning[_].enabled
    msg := sprintf("Storage bucket %s should have versioning enabled for data protection.", [resource.address])
}

warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    not resource.change.after.lifecycle_rule
    msg := sprintf("Storage bucket %s should have lifecycle rules for cost optimization.", [resource.address])
}