terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Authentication comes from the environment (AWS_PROFILE or AWS_* variables).
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      lab   = "cloud-lab"
      layer = "0"
    }
  }
}
