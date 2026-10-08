terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Layer 0 root with its own state key. Values come from backend.local.hcl (gitignored):
  #   terraform init -backend-config=backend.local.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      lab    = "cloud-lab"
      layer  = "0"
      domain = "identity"
    }
  }
}
