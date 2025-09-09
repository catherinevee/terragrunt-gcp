# Terraform Modules

## Structure
```
modules/
├── _templates/     # Module templates for new modules
├── compute/        # Compute resources (GKE, Cloud Run, etc.)
├── data/          # Data resources (Cloud SQL, BigQuery, etc.)
├── networking/    # Network resources (VPC, Subnets, etc.)
└── security/      # Security resources (IAM, KMS, etc.)
```

## Available Modules

### Compute
- `gke` - Google Kubernetes Engine cluster

### Data
- `cloud-sql` - Cloud SQL database instances

### Networking
- `vpc` - Virtual Private Cloud network
- `subnets` - VPC subnet configuration
- `firewall` - Firewall rules
- `nat` - Cloud NAT gateway

### Security
- `iam` - IAM roles and policies

## Creating New Modules

1. Copy a template from `_templates/`:
   - `basic/` - Simple module structure
   - `complete/` - Full module with examples

2. Update the template variables:
   - Replace `${module_name}` with your module name
   - Replace `${resource_type}` with the GCP resource type
   - Update variables and outputs as needed

3. Add documentation:
   - Update the README.md
   - Add usage examples
   - Document all inputs and outputs

## Module Standards

- All modules must have:
  - `main.tf` - Main resource definitions
  - `variables.tf` - Input variables
  - `outputs.tf` - Output values
  - `README.md` - Documentation

- Optional files:
  - `versions.tf` - Provider version constraints
  - `locals.tf` - Local values
  - `data.tf` - Data sources
