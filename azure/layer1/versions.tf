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

  # Partial configuration. Values come from backend.local.hcl (gitignored):
  #   terraform init -backend-config=backend.local.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    storage {
      # CLOUD-26: the storage account is read through the management plane only. Layer 1 uses no
      # queue_properties or static_website, and with public network access closed the data plane
      # read would fail on refresh and on destroy.
      data_plane_available = false
    }
  }
  storage_use_azuread = true
}
