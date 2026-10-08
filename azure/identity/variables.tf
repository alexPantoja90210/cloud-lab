variable "resource_group_name" {
  description = "Layer 0 resource group (created by azure/bootstrap) that scopes the role."
  type        = string
  default     = "rg-cloud-lab"
}
