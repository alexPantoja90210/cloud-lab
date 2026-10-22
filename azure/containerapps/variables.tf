variable "resource_group_name" {
  description = "Existing resource group that holds the environment and the app."
  type        = string
  default     = "rg-cloud-lab"
}

variable "environment_name" {
  description = "Container Apps environment name. A different name from the hand-built run (cae-cloud-lab) so both can coexist."
  type        = string
  default     = "cae-cloud-lab-tf"
}

variable "app_name" {
  description = "Container App name."
  type        = string
  default     = "ca-hello-tf"
}

variable "image" {
  description = "Sample image used in the hand-built run, so the numbers are comparable."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
