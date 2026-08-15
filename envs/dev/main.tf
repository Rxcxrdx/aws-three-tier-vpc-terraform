module "network" {
  source = "../../modules/network"

  name     = "dev"
  vpc_cidr = "10.0.0.0/16"
  az_count = 2

  # Un solo NAT: si cae esa zona, ambas subredes privadas pierden la salida.
  # Aceptable en desarrollo; producción usaría per_az.
  nat_strategy = "single"

  tags = {
    Environment = "dev"
  }
}

module "security" {
  source = "../../modules/security"

  name = "dev"

  # Estas referencias son lo que ordena la creación: primero la red.
  vpc_id          = module.network.vpc_id
  vpc_cidr        = module.network.vpc_cidr
  data_subnet_ids = module.network.data_subnet_ids

  tags = {
    Environment = "dev"
  }
}
