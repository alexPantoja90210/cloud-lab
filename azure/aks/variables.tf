variable "resource_group_name" {
  description = "Existing resource group that holds the cluster."
  type        = string
  default     = "rg-cloud-lab"
}

variable "cluster_name" {
  description = "AKS cluster name. A different name from the hand-built run (aks-cloud-lab) so both can coexist."
  type        = string
  default     = "aks-cloud-lab-tf"
}

variable "node_vm_size" {
  description = "VM size of the single system node."
  type        = string
  default     = "Standard_D2als_v7"
}

variable "node_count" {
  description = "Number of nodes. Cost is about 0.0804 USD/h per node plus about 0.03 USD/h for the standard load balancer and its outbound IP."
  type        = number
  default     = 1
}
