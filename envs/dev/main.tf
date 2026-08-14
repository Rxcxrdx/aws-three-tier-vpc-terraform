# Esto es el "resultado" de todo lo que escribiste en modules/network.
# Un módulo no se ejecuta solo: se llama desde un directorio raíz, con
# un bloque "module".

module "network" {
  # Ruta relativa DESDE ESTE ARCHIVO hasta el módulo.
  source = "../../modules/network"

  # Estos son exactamente los argumentos = tus variables.tf del módulo.
  # "name" no tiene default en el módulo, así que es obligatorio pasarlo.
  name         = "dev"
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 2
  nat_strategy = "single"


  tags = {
    Environment = "dev"
  }
}

module "security" {
  source = "../../modules/security"

  vpc_id          = module.network.vpc_id
  vpc_cidr        = module.network.vpc_cidr
  data_subnet_ids = module.network.data_subnet_ids
  name            = "dev"
  tags            = { Environment = "dev" }
}