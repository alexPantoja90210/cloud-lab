variable "location" {
  description = "Azure region for layer 0 and the layer 1 resource group."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Single resource group that is the layer 1 container. Created empty here, never destroyed."
  type        = string
  default     = "rg-cloud-lab"
}
