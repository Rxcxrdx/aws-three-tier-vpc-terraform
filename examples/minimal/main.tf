# Ejemplo autocontenido: estado local, sin backend remoto ni bootstrap.
#
#   terraform init && terraform apply

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "aws-three-tier-vpc-terraform"
      Example   = "minimal"
      ManagedBy = "terraform"
    }
  }
}

variable "region" {
  description = "Región donde desplegar el ejemplo. Funciona en cualquiera."
  type        = string
  default     = "us-east-1"
}

module "network" {
  source = "../../modules/network"

  name     = "example"
  vpc_cidr = "10.20.0.0/16"
  az_count = 2

  # Desactivados para que el ejemplo no deje infraestructura persistente.
  nat_strategy         = "none"
  enable_ssm_endpoints = false
}

module "security" {
  source = "../../modules/security"

  name = "example"

  vpc_id          = module.network.vpc_id
  vpc_cidr        = module.network.vpc_cidr
  data_subnet_ids = module.network.data_subnet_ids
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "subnets_by_tier" {
  description = "Las 6 subredes creadas, agrupadas por capa."
  value = {
    public  = module.network.public_subnet_ids
    private = module.network.private_subnet_ids
    data    = module.network.data_subnet_ids
  }
}

output "security_group_ids" {
  value = {
    alb = module.security.alb_security_group_id
    app = module.security.app_security_group_id
    db  = module.security.db_security_group_id
  }
}
