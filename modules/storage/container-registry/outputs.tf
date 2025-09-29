# Container Registry Module Outputs

output "registry_id" {
  description = "The ID of the container registry"
  value       = google_container_registry.registry.id
}

output "registry_bucket_name" {
  description = "The name of the GCS bucket backing the registry"
  value       = google_container_registry.registry.bucket_self_link
}

output "registry_location" {
  description = "The location of the container registry"
  value       = var.location
}

output "registry_project" {
  description = "The project where the registry is created"
  value       = google_container_registry.registry.project
}

output "registry_url" {
  description = "The URL of the container registry"
  value       = "${var.location}.gcr.io/${var.project_id}"
}

output "registry_hostname" {
  description = "The hostname of the container registry"
  value       = "${var.location}.gcr.io"
}

output "artifact_registry_repositories" {
  description = "Map of Artifact Registry repository details"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => {
      id                     = v.id
      name                   = v.name
      location               = v.location
      format                 = v.format
      description            = v.description
      labels                 = v.labels
      kms_key_name           = v.kms_key_name
      repository_id          = v.repository_id
      create_time            = v.create_time
      update_time            = v.update_time
      mode                   = v.mode
      cleanup_policy_dry_run = v.cleanup_policy_dry_run
    }
  }
}

output "artifact_registry_repository_ids" {
  description = "Map of repository names to their IDs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.id
  }
}

output "artifact_registry_repository_names" {
  description = "List of Artifact Registry repository names"
  value = [
    for repo in google_artifact_registry_repository.repositories : repo.name
  ]
}

output "docker_repositories" {
  description = "Map of Docker format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "DOCKER"
  }
}

output "maven_repositories" {
  description = "Map of Maven format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "MAVEN"
  }
}

output "npm_repositories" {
  description = "Map of NPM format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "NPM"
  }
}

output "python_repositories" {
  description = "Map of Python format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "PYTHON"
  }
}

output "apt_repositories" {
  description = "Map of APT format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "APT"
  }
}

output "yum_repositories" {
  description = "Map of YUM format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "YUM"
  }
}

output "helm_repositories" {
  description = "Map of Helm format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "HELM"
  }
}

output "go_repositories" {
  description = "Map of Go format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "GO"
  }
}

output "kfp_repositories" {
  description = "Map of KFP (Kubeflow Pipeline) format repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
    if v.format == "KFP"
  }
}

output "repository_iam_bindings" {
  description = "Map of repository IAM bindings"
  value = {
    for k, v in google_artifact_registry_repository_iam_binding.bindings : k => {
      repository = v.repository
      role       = v.role
      members    = v.members
      condition  = v.condition
    }
  }
}

output "repository_iam_members" {
  description = "Map of individual repository IAM member bindings"
  value = {
    for k, v in google_artifact_registry_repository_iam_member.members : k => {
      repository = v.repository
      role       = v.role
      member     = v.member
      condition  = v.condition
    }
  }
}

output "repository_readers" {
  description = "Map of repositories to their reader members"
  value = {
    for k, v in google_artifact_registry_repository_iam_binding.bindings : k => v.members
    if v.role == "roles/artifactregistry.reader"
  }
}

output "repository_writers" {
  description = "Map of repositories to their writer members"
  value = {
    for k, v in google_artifact_registry_repository_iam_binding.bindings : k => v.members
    if v.role == "roles/artifactregistry.writer"
  }
}

output "repository_admins" {
  description = "Map of repositories to their admin members"
  value = {
    for k, v in google_artifact_registry_repository_iam_binding.bindings : k => v.members
    if v.role == "roles/artifactregistry.admin"
  }
}

output "repository_cleanup_policies" {
  description = "Map of repositories to their cleanup policies"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.cleanup_policies
  }
}

output "repository_maven_configs" {
  description = "Map of repositories to their Maven configurations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.maven_config
    if v.format == "MAVEN"
  }
}

output "repository_docker_configs" {
  description = "Map of repositories to their Docker configurations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.docker_config
    if v.format == "DOCKER"
  }
}

output "repository_virtual_configs" {
  description = "Map of virtual repositories to their configurations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.virtual_repository_config
    if v.mode == "VIRTUAL_REPOSITORY"
  }
}

output "repository_remote_configs" {
  description = "Map of remote repositories to their configurations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.remote_repository_config
    if v.mode == "REMOTE_REPOSITORY"
  }
}

output "repository_upstream_credentials" {
  description = "Map of repositories to their upstream credentials"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.remote_repository_config[0].upstream_credentials
    if v.mode == "REMOTE_REPOSITORY" && length(v.remote_repository_config) > 0
  }
  sensitive = true
}

output "cmek_encrypted_repositories" {
  description = "Map of CMEK-encrypted repositories to their KMS key names"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.kms_key_name
    if v.kms_key_name != null
  }
}

output "vulnerability_scanning_configs" {
  description = "Map of repositories to their vulnerability scanning configurations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.vulnerability_scanning
  }
}

output "sbom_configs" {
  description = "Map of repositories to their SBOM configurations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.sbom_config
  }
}

output "gcr_service_account" {
  description = "The service account for Google Container Registry"
  value       = data.google_storage_project_service_account.gcr_account.email_address
}

output "artifact_registry_service_account" {
  description = "The service account for Artifact Registry"
  value       = "service-${data.google_project.project.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
}

output "registry_bucket_iam_bindings" {
  description = "Map of GCR bucket IAM bindings"
  value = {
    for k, v in google_storage_bucket_iam_binding.gcr_bindings : k => {
      bucket  = v.bucket
      role    = v.role
      members = v.members
    }
  }
}

output "repository_locations" {
  description = "List of all unique repository locations"
  value = distinct([
    for repo in google_artifact_registry_repository.repositories : repo.location
  ])
}

output "repository_formats" {
  description = "List of all unique repository formats in use"
  value = distinct([
    for repo in google_artifact_registry_repository.repositories : repo.format
  ])
}

output "total_repositories_count" {
  description = "Total number of Artifact Registry repositories"
  value       = length(google_artifact_registry_repository.repositories)
}

output "repositories_by_format" {
  description = "Count of repositories grouped by format"
  value = {
    for format in distinct([for r in google_artifact_registry_repository.repositories : r.format]) :
    format => length([for r in google_artifact_registry_repository.repositories : r if r.format == format])
  }
}

output "repositories_by_location" {
  description = "Count of repositories grouped by location"
  value = {
    for location in distinct([for r in google_artifact_registry_repository.repositories : r.location]) :
    location => length([for r in google_artifact_registry_repository.repositories : r if r.location == location])
  }
}

output "repositories_by_mode" {
  description = "Count of repositories grouped by mode"
  value = {
    standard = length([for r in google_artifact_registry_repository.repositories : r if r.mode == "STANDARD_REPOSITORY"]),
    virtual  = length([for r in google_artifact_registry_repository.repositories : r if r.mode == "VIRTUAL_REPOSITORY"]),
    remote   = length([for r in google_artifact_registry_repository.repositories : r if r.mode == "REMOTE_REPOSITORY"])
  }
}

output "docker_registry_urls" {
  description = "Map of Docker repositories to their registry URLs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    "${v.location}-docker.pkg.dev/${var.project_id}/${v.repository_id}"
    if v.format == "DOCKER"
  }
}

output "maven_registry_urls" {
  description = "Map of Maven repositories to their registry URLs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    "https://${v.location}-maven.pkg.dev/${var.project_id}/${v.repository_id}"
    if v.format == "MAVEN"
  }
}

output "npm_registry_urls" {
  description = "Map of NPM repositories to their registry URLs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    "https://${v.location}-npm.pkg.dev/${var.project_id}/${v.repository_id}"
    if v.format == "NPM"
  }
}

output "python_registry_urls" {
  description = "Map of Python repositories to their registry URLs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    "https://${v.location}-python.pkg.dev/${var.project_id}/${v.repository_id}/simple/"
    if v.format == "PYTHON"
  }
}

output "go_registry_urls" {
  description = "Map of Go repositories to their registry URLs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    "${v.location}-go.pkg.dev/${var.project_id}/${v.repository_id}"
    if v.format == "GO"
  }
}

output "helm_registry_urls" {
  description = "Map of Helm repositories to their registry URLs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    "oci://${v.location}-docker.pkg.dev/${var.project_id}/${v.repository_id}"
    if v.format == "HELM"
  }
}

output "repository_tags" {
  description = "Map of repository tags for organization"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.labels
  }
}

output "cleanup_policy_summaries" {
  description = "Summary of cleanup policies across repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => {
      has_cleanup_policy = length(v.cleanup_policies) > 0
      dry_run_enabled    = v.cleanup_policy_dry_run
      policy_count       = length(v.cleanup_policies)
    }
  }
}

output "repository_immutable_tags" {
  description = "Map of repositories with immutable tag configurations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    try(v.docker_config[0].immutable_tags, false)
    if v.format == "DOCKER" && length(v.docker_config) > 0
  }
}

output "repository_public_access" {
  description = "Map of repositories with public access configuration"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k =>
    contains(try(flatten([for b in google_artifact_registry_repository_iam_binding.bindings : b.members if b.repository == v.id && b.role == "roles/artifactregistry.reader"]), []), "allUsers")
  }
}

output "enabled_apis" {
  description = "List of APIs that should be enabled for container registry"
  value = [
    "containerregistry.googleapis.com",
    "artifactregistry.googleapis.com",
    "containeranalysis.googleapis.com",
    "binaryauthorization.googleapis.com"
  ]
}

output "gcr_image_pull_secrets" {
  description = "Kubernetes image pull secret configuration for GCR"
  value = {
    server   = "${var.location}.gcr.io"
    username = "_json_key"
    email    = data.google_storage_project_service_account.gcr_account.email_address
  }
  sensitive = true
}

output "artifact_registry_pull_commands" {
  description = "Example pull commands for different repository formats"
  value = {
    docker = "docker pull ${var.location}-docker.pkg.dev/${var.project_id}/REPOSITORY/IMAGE:TAG"
    maven  = "mvn deploy -DaltDeploymentRepository=artifact-registry::default::https://${var.location}-maven.pkg.dev/${var.project_id}/REPOSITORY"
    npm    = "npm config set @SCOPE:registry https://${var.location}-npm.pkg.dev/${var.project_id}/REPOSITORY"
    python = "pip install --index-url https://${var.location}-python.pkg.dev/${var.project_id}/REPOSITORY/simple/ PACKAGE"
    go     = "GOPROXY=${var.location}-go.pkg.dev/${var.project_id}/REPOSITORY,https://proxy.golang.org GO111MODULE=on go get PACKAGE"
  }
}

output "repository_sizes" {
  description = "Map of repositories to their storage sizes"
  value = {
    for k, v in data.google_artifact_registry_repository.repo_data : k => v.size_bytes
  }
}

output "repository_artifact_counts" {
  description = "Map of repositories to their artifact counts"
  value = {
    for k, v in data.google_artifact_registry_repository.repo_data : k => v.artifact_count
  }
}