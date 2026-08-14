# =============================================================================
#  Entorno dev: la composición concreta de los módulos.
#
#  Un módulo no se ejecuta solo. Este directorio es lo que le da valores a
#  sus variables y decide el compromiso entre coste y disponibilidad. El
#  mismo par de módulos con otros valores es otro entorno.
# =============================================================================

module "network" {
  source = "../../modules/network"

  name     = "dev"
  vpc_cidr = "10.0.0.0/16"
  az_count = 2

  # Un solo NAT compartido. Si cae esa zona, las subredes privadas de ambas
  # pierden la salida a internet — asumible en desarrollo, donde el ahorro
  # pesa más que la disponibilidad. Un entorno de producción usaría "per_az".
  nat_strategy = "single"

  tags = {
    Environment = "dev"
  }
}

module "security" {
  source = "../../modules/security"

  name = "dev"

  # Estas referencias son la dependencia entre ambos módulos: Terraform
  # deduce de aquí que la red se crea antes que los firewalls.
  vpc_id          = module.network.vpc_id
  vpc_cidr        = module.network.vpc_cidr
  data_subnet_ids = module.network.data_subnet_ids

  tags = {
    Environment = "dev"
  }
}
