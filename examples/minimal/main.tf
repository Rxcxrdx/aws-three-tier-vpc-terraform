# =============================================================================
#  Ejemplo mínimo: la arquitectura completa, sin coste y sin preparativos.
#
#  A diferencia de envs/dev, este directorio NO usa backend remoto. El state
#  se queda en un archivo local, así que no hace falta ejecutar el bootstrap
#  ni tener un bucket propio: basta con credenciales de AWS.
#
#      terraform init
#      terraform apply
#      terraform destroy
#
#  Los dos recursos que cobran por hora están apagados a propósito (ver
#  abajo). Lo que queda —VPC, subredes, rutas, security groups, NACL y flow
#  logs— no genera cargo alguno.
# =============================================================================

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

  # Los dos interruptores que mantienen el ejemplo en cero:
  #
  #   nat_strategy = "none"    → sin NAT Gateway. Las subredes privadas se
  #                              quedan sin salida a internet, que para ver
  #                              la topología no hace falta.
  #   enable_ssm_endpoints     → los interface endpoints cobran por hora y
  #                              por zona.
  #
  # Para ver la arquitectura tal como se despliega de verdad, cámbialos a
  # "single" y true, y lee antes la tabla de costes del README.
  nat_strategy         = "none"
  enable_ssm_endpoints = false
}

module "security" {
  source = "../../modules/security"

  name = "example"

  # Las salidas de un módulo alimentan las entradas del otro: es Terraform
  # quien deduce de aquí que la red debe existir antes que los firewalls.
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
