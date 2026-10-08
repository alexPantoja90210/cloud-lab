variable "resource_group_name" {
  description = "Layer 0 resource group that holds layer 1 resources."
  type        = string
  default     = "rg-cloud-lab"
}

variable "identity_name" {
  description = "Managed identity created by azure/identity (layer 0)."
  type        = string
  default     = "id-cloud-lab-reader"
}

variable "identity_resource_group_name" {
  description = "Layer 0 resource group that holds the managed identity (azure/identity)."
  type        = string
  default     = "rg-cloud-lab-identity"
}
