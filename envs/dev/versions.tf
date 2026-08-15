# El provider se configura aquí, no en los módulos: los módulos lo heredan de
# quien los llama, y por eso funcionan en otra región sin tocarlos.

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

  # Se aplican a todo recurso que admita etiquetado, sin repetirlos.
  default_tags {
    tags = {
      Project     = "aws-three-tier-vpc-terraform"
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}
