# El provider se configura en el directorio raíz, no dentro de los módulos:
# los módulos heredan el provider de quien los llama. Eso es lo que permite
# desplegar los mismos módulos en otra región o con otras credenciales sin
# tocarlos.

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

  # default_tags aplica estos tags a todo recurso que soporte etiquetado,
  # sin repetirlos en cada bloque. Son los que permiten después filtrar el
  # gasto por proyecto y por entorno en Cost Explorer.
  default_tags {
    tags = {
      Project     = "aws-three-tier-vpc-terraform"
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}
