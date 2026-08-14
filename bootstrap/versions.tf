terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "Región donde crear el bucket de state."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Responsable de la infraestructura. Aparece como tag en cada recurso."
  type        = string
  default     = "unassigned"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "aws-three-tier-vpc-terraform"
      ManagedBy = "terraform"
      Owner     = var.owner
    }
  }
}
