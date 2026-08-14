# =============================================================================
#  Pruebas del módulo de seguridad.
#
#  Estas van con apply y no con plan, y la razón es interesante: lo que hay
#  que demostrar es que una regla apunta al ID de otro security group, y ese
#  ID no existe hasta que AWS lo crea. En plan aparece como "known after
#  apply" y la aserción no se puede evaluar. Lo mismo con el security group
#  por defecto, que se adopta de una VPC real: sin VPC no hay nada que
#  adoptar.
#
#  Security groups, NACLs, VPC y subredes no cuestan nada, así que la suite
#  sigue sin generar factura. Todo se destruye en el teardown.
# =============================================================================


# Andamio: una VPC de usar y tirar. Ver tests/setup/main.tf.
run "setup_vpc" {
  command = apply

  module {
    source = "./tests/setup"
  }
}


run "las_capas_se_referencian_entre_si_nunca_por_ip" {
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

  # Se compara contra el security group real del balanceador, no solo que no
  # sea nulo: así también falla si alguien reapunta la regla a otro grupo.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.referenced_security_group_id == aws_security_group.alb.id
    error_message = "El SG de app debe referenciar el SG del ALB."
  }

  # Sustituir la referencia por un CIDR de subred es el atajo habitual
  # cuando algo no conecta: funciona, no da error, y abre la capa a
  # cualquier cosa que aterrice en esa subred.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv4 == null
    error_message = "La regla app-desde-alb no debe tener un CIDR fijo."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.referenced_security_group_id == aws_security_group.app.id
    error_message = "El SG de la base de datos debe referenciar el SG de app."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.cidr_ipv4 == null
    error_message = "La regla db-desde-app no debe tener un CIDR fijo."
  }

  # El único 0.0.0.0/0 legítimo vive en el balanceador. Se afirma para dejar
  # constancia de dónde está permitido y de que no se ha movido.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_https.cidr_ipv4 == "0.0.0.0/0"
    error_message = "El SG del ALB debe aceptar HTTPS desde internet."
  }
}


run "el_security_group_por_defecto_queda_sin_reglas" {
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
    error_message = "El security group por defecto debe quedar sin reglas de entrada."
  }

  assert {
    condition     = length(aws_default_security_group.this.egress) == 0
    error_message = "El security group por defecto debe quedar sin reglas de salida."
  }
}


run "el_nacl_de_datos_solo_permite_trafico_interno" {
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
    condition     = aws_network_acl_rule.data_egress_vpc.cidr_block == run.setup_vpc.vpc_cidr
    error_message = "La salida del NACL de datos debe limitarse al CIDR de la VPC."
  }

  assert {
    condition     = aws_network_acl_rule.data_ingress_vpc.cidr_block == run.setup_vpc.vpc_cidr
    error_message = "La entrada del NACL de datos debe limitarse al CIDR de la VPC."
  }
}
