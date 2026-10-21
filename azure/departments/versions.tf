terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Own state key. Values come from backend.local.hcl (gitignored):
  #   terraform init -backend-config=backend.local.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

provider "azuread" {}
