# Module: ${module_name}
# Description: ${module_description}

resource "google_${resource_type}" "this" {
  name    = var.name
  project = var.project_id
  
  # Add resource-specific configuration
  
  labels = var.labels
}
