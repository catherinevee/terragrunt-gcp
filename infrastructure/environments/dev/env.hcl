# Dev environment configuration
locals {
  project_id  = "acme-ecommerce-platform-dev"
  environment = "dev"

  # Environment labels
  environment_labels = {
    environment         = "dev"
    business_unit       = "ecommerce"
    application         = "ecommerce-platform"
    cost_center         = "development"
    data_classification = "internal"
  }
}
