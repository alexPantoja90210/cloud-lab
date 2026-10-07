terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

# Authentication comes from the environment (az login, or ARM_* variables).
# The subscription is taken from ARM_SUBSCRIPTION_ID so it is never written here.
provider "azurerm" {
  features {}
  storage_use_azuread = true
}
