variable "resource_group_name" {
  description = "Resource group that holds the department storage accounts."
  type        = string
  default     = "rg-cloud-lab"
}

variable "departments" {
  description = "Department key => container name. 'hr' needs a longer container name (minimum is 3 characters)."
  type        = map(string)
  default = {
    finance     = "finance"
    hr          = "human-resources"
    operations  = "operations"
    engineering = "engineering"
  }
}

variable "members" {
  description = "Department key => object IDs of the principals that belong to that department's group. Moving a person between departments means editing this map and nothing else."
  type        = map(list(string))
  default     = {}
}

variable "group_prefix" {
  description = "Prefix of the Entra group names. The Terraform twin uses a different prefix from the hand-built run so both can coexist."
  type        = string
  default     = "grp"
}
