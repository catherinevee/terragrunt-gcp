# PowerShell script to import existing GCP resources into Terraform state

Write-Host "Starting resource import process..."

# Import custom role
Write-Host "Importing custom role..."
terraform import 'module.iam.google_project_iam_custom_role.custom_roles["terraform-custom-role-v2"]' projects/acme-ecommerce-platform-dev/roles/terraform_custom_role_v2

# Import workload identity pool
Write-Host "Importing workload identity pool..."
terraform import 'module.iam.google_iam_workload_identity_pool.workload_identity_pool[0]' projects/acme-ecommerce-platform-dev/locations/global/workloadIdentityPools/github-actions

# Import workload identity pool provider
Write-Host "Importing workload identity pool provider..."
terraform import 'module.iam.google_iam_workload_identity_pool_provider.workload_identity_pool_provider[0]' projects/acme-ecommerce-platform-dev/locations/global/workloadIdentityPools/github-actions/providers/github-actions-provider

# Import existing secrets
Write-Host "Importing existing secrets..."
terraform import 'module.secret_manager.google_secret_manager_secret.secrets["api-key"]' projects/acme-ecommerce-platform-dev/secrets/api-key

Write-Host "Resource import process completed!"
