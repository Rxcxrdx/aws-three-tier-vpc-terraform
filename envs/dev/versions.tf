# Mismo bloque que bootstrap/versions.tf. El provider vive en cada
# directorio raíz, no dentro de los módulos: los módulos HEREDAN el
# provider de quien los llama.

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
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "aws-three-tier-vpc-terraform"
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = "ricardo"
    }
  }
}