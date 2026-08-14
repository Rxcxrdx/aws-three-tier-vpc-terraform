# =============================================================================
#  Pruebas del módulo de seguridad: HU-02 (SG default vacío) y HU-04 (los
#  firewalls se refieren entre sí, nunca por IP fija).
#
#  ¿Por qué apply y no plan?
#  Las dos cosas que hay que demostrar solo existen después del apply:
#    - referenced_security_group_id es el ID del SG del ALB, y un ID no se
#      conoce hasta que AWS lo crea. En plan es "(known after apply)" y la
#      aserción revienta con "Unknown condition value".
#    - aws_default_security_group ADOPTA el SG que AWS ya creó junto a la
#      VPC. Sin VPC real no hay nada que adoptar, y sus reglas tampoco se
#      conocen en plan.
#  El coste es cero: VPC, subredes, security groups y NACLs son gratis.
#  Todo se destruye en el teardown de este mismo fichero.
# =============================================================================


# Levanta la VPC efímera sobre la que se plantan los security groups.
# Ver tests/setup/main.tf: deliberadamente NO usa ./modules/network para no
# arrastrar NAT Gateways ni endpoints a una prueba unitaria.
run "setup_vpc" {
  command = apply

  module {
    source = "./tests/setup"
  }
}


run "hu04_app_sg_references_alb_not_cidr" {
  command = apply

  module {
    source = "./modules/security"
  }

  variables {
    vpc_id          = run.setup_vpc.vpc_id
    vpc_cidr        = run.setup_vpc.vpc_cidr
    name            = "tftest"
    data_subnet_ids = run.setup_vpc.data_subnet_ids
  }

  # La regla de entrada de "app" debe apuntar al SG del ALB por su ID.
  # No basta con que no sea null: se compara contra el SG real del ALB, así
  # que si alguien la reapunta a otro grupo, esto también lo atrapa.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.referenced_security_group_id == aws_security_group.alb.id
    error_message = "El SG de app debe referenciar el SG del ALB, no un CIDR."
  }

  # Y su cidr_ipv4 debe estar vacío. Si alguien la reescribe con un CIDR
  # fijo entre capas, este test lo atrapa.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv4 == null
    error_message = "La regla app-desde-alb no debe tener un CIDR fijo."
  }

  # La misma regla vale para el salto app → base de datos.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.referenced_security_group_id == aws_security_group.app.id
    error_message = "El SG de la base de datos debe referenciar el SG de app, no un CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.cidr_ipv4 == null
    error_message = "La regla db-desde-app no debe tener un CIDR fijo."
  }

  # El único que sí abre a internet es el ALB: es su trabajo. Se afirma
  # explícitamente para que quede claro que el 0.0.0.0/0 vive ahí y solo ahí.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_https.cidr_ipv4 == "0.0.0.0/0"
    error_message = "El SG del ALB debe aceptar HTTPS desde internet."
  }
}


run "hu02_default_sg_is_empty" {
  command = apply

  module {
    source = "./modules/security"
  }

  variables {
    vpc_id          = run.setup_vpc.vpc_id
    vpc_cidr        = run.setup_vpc.vpc_cidr
    name            = "tftest"
    data_subnet_ids = run.setup_vpc.data_subnet_ids
  }

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0
    error_message = "El security group default debe quedar sin reglas de entrada."
  }

  assert {
    condition     = length(aws_default_security_group.this.egress) == 0
    error_message = "El security group default debe quedar sin reglas de salida."
  }
}
