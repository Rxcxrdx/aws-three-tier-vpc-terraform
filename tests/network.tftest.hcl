# =============================================================================
#  Prueba los criterios de aceptación de HU-02, HU-03 y HU-04 directamente
#  sobre el plan, sin necesidad de aplicar nada en AWS.
# =============================================================================

# command = plan → no crea nada real, solo evalúa el plan. Rápido y gratis.
run "creates_expected_subnet_count" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name     = "test"
    vpc_cidr = "10.0.0.0/16"
    az_count = 2
  }

  # 3 capas x 2 AZs = 6. Si alguien rompe el for anidado, esto lo atrapa
  # antes de que llegue a producción.
  assert {
    condition     = length(aws_subnet.this) == 6
    error_message = "Se esperaban 6 subredes (3 capas x 2 AZs)."
  }
}


run "hu03_data_layer_has_no_internet_route" {
  command = apply

  module {
    source = "./modules/network"
  }

  variables {
    name     = "test"
    vpc_cidr = "10.0.0.0/16"
    az_count = 2
  }

  # HU-03: "la capa de datos no tiene ruta 0.0.0.0/0"
  # alltrue() sobre un for que revisa TODAS las rutas de la tabla de datos.
  assert {
    condition = alltrue([
      for r in aws_route_table.data.route : r.cidr_block != "0.0.0.0/0"
    ])
    error_message = "La tabla de rutas de datos no debe tener ruta a internet (0.0.0.0/0)."
  }
}


run "hu02_data_subnets_have_no_public_ip" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name     = "test"
    vpc_cidr = "10.0.0.0/16"
    az_count = 2
  }

  # Ninguna subred de datos debe asignar IP pública automática.
  assert {
    condition = alltrue([
      for k, v in aws_subnet.this : v.map_public_ip_on_launch == false
      if v.tags.Tier == "data"
    ])
    error_message = "Las subredes de datos no deben asignar IP publica automatica."
  }
}


run "hu05_dns_enabled_for_ssm" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name     = "test"
    vpc_cidr = "10.0.0.0/16"
    az_count = 2
  }

  # Prerrequisito silencioso de SSM que detectamos desde el spec v2.
  # Si alguien lo desactiva sin querer, esto falla en 2 segundos en vez
  # de fallar 3 fases despues con un error críptico de SSM.
  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "DNS debe estar habilitado en la VPC: es prerrequisito de los VPC Endpoints de SSM."
  }
}


run "validates_cidr_offsets_are_correct" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name     = "test"
    vpc_cidr = "10.0.0.0/16"
    az_count = 2
  }

  # Verifica que el offset+idx haya calculado el bloque correcto,
  # no solo que exista una subred con ese nombre.
  assert {
    condition     = aws_subnet.this["public-us-east-1a"].cidr_block == "10.0.0.0/24"
    error_message = "La primera subred publica debe ser 10.0.0.0/24."
  }

  assert {
    condition     = aws_subnet.this["private-us-east-1a"].cidr_block == "10.0.16.0/24"
    error_message = "La primera subred privada debe ser 10.0.16.0/24 (offset 16)."
  }
}