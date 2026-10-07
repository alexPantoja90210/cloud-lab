terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial configuration. Values come from backend.local.hcl (gitignored):
  #   terraform init -backend-config=backend.local.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region

  # The AWS equivalent of Azure's single resource group: every layer 1 resource carries these tags,
  # so "is anything left?" is one tag query, and destroy has a clean target.
  default_tags {
    tags = {
      lab   = "cloud-lab"
      layer = "1"
    }
  }
}
