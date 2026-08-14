# =============================================================================
#  Pruebas del módulo de red.
#
#  Todas se ejecutan con nat_strategy = "none" y los endpoints apagados, de
#  forma que la suite completa no crea ni un solo recurso facturable. Correr
#  los tests no debería costar dinero ni hacer pensar en ello.
#
#      terraform test
# =============================================================================

variables {
  name                 = "test"
  vpc_cidr             = "10.0.0.0/16"
  az_count             = 2
  nat_strategy         = "none"
  enable_ssm_endpoints = false
}


run "crea_una_subred_por_capa_y_zona" {
  command = plan

  module {
    source = "./modules/network"
  }

  # 3 capas x 2 zonas. Si alguien rompe el doble bucle que arma el mapa de
  # subredes, el conteo lo delata antes de llegar a AWS.
  assert {
    condition     = length(aws_subnet.this) == 6
    error_message = "Se esperaban 6 subredes (3 capas x 2 zonas)."
  }
}


run "los_cidr_respetan_el_offset_de_cada_capa" {
  command = plan

  module {
    source = "./modules/network"
  }

  # No basta con que exista una subred con ese nombre: se comprueba que el
  # cálculo offset + índice haya dado el bloque correcto.
  assert {
    condition     = aws_subnet.this["public-us-east-1a"].cidr_block == "10.0.0.0/24"
    error_message = "La primera subred pública debe ser 10.0.0.0/24."
  }

  assert {
    condition     = aws_subnet.this["private-us-east-1a"].cidr_block == "10.0.16.0/24"
    error_message = "La primera subred privada debe ser 10.0.16.0/24 (offset 16)."
  }

  assert {
    condition     = aws_subnet.this["data-us-east-1b"].cidr_block == "10.0.33.0/24"
    error_message = "La segunda subred de datos debe ser 10.0.33.0/24 (offset 32 + zona 1)."
  }
}


run "las_subredes_de_datos_no_reciben_ip_publica" {
  command = plan

  module {
    source = "./modules/network"
  }

  assert {
    condition = alltrue([
      for k, v in aws_subnet.this : v.map_public_ip_on_launch == false
      if v.tags.Tier == "data"
    ])
    error_message = "Las subredes de datos no deben asignar IP pública automática."
  }
}


run "la_capa_de_datos_no_tiene_ruta_a_internet" {
  # Este necesita apply: las rutas de una tabla son un atributo calculado y
  # en plan aparecen como desconocidas. Sin NAT ni endpoints, aplicar la red
  # completa sigue sin costar nada.
  command = apply

  module {
    source = "./modules/network"
  }

  assert {
    condition = alltrue([
      for r in aws_route_table.data.route : r.cidr_block != "0.0.0.0/0"
    ])
    error_message = "La tabla de rutas de datos no debe tener ruta a internet (0.0.0.0/0)."
  }
}


run "el_dns_esta_activo_porque_ssm_depende_de_el" {
  command = plan

  module {
    source = "./modules/network"
  }

  # Prerrequisito silencioso: sin resolución DNS los interface endpoints no
  # resuelven sus nombres privados y Session Manager no conecta. El fallo
  # aparece mucho después y no menciona el DNS, así que se vigila aquí.
  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "El DNS debe estar activo en la VPC: es prerrequisito de los endpoints de SSM."
  }
}


run "sin_nat_las_subredes_privadas_quedan_sin_salida" {
  command = plan

  module {
    source = "./modules/network"
  }

  # Verifica el interruptor de coste: con nat_strategy = "none" no debe
  # crearse ningún NAT Gateway ni ninguna IP elástica.
  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "Con nat_strategy = none no debe crearse ningún NAT Gateway."
  }

  assert {
    condition     = length(aws_eip.nat) == 0
    error_message = "Con nat_strategy = none no debe reservarse ninguna IP elástica."
  }
}


run "un_nat_por_zona_cuando_la_estrategia_es_per_az" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    nat_strategy = "per_az"
  }

  # Con per_az cada zona tiene el suyo: es lo que evita que la caída de una
  # zona deje sin salida a las demás.
  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Con nat_strategy = per_az debe haber un NAT por zona."
  }
}
