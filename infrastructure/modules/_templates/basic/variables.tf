variable "name" {
  description = "Resource name"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}
