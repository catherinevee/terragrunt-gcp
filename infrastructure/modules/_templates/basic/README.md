# Module Name

## Description
Brief description of what this module does.

## Usage
```hcl
module "example" {
  source = "../../modules/category/name"
  
  name       = "my-resource"
  project_id = var.project_id
}
```

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Resource name | string | n/a | yes |
| project_id | GCP Project ID | string | n/a | yes |

## Outputs
| Name | Description |
|------|-------------|
| id | Resource ID |
| name | Resource name |
