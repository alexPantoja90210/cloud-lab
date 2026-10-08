variable "region" {
  description = "AWS region (IAM is global; this is only the provider's API endpoint)."
  type        = string
  default     = "us-east-1"
}

variable "trusted_user_name" {
  description = "Name of the IAM user allowed to assume the lab role. Supplied from identity.local.tfvars (gitignored), never committed."
  type        = string
}
