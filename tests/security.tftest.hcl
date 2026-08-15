# Pruebas del módulo de seguridad. Van con apply porque los identificadores de
# security group no existen hasta entonces, y el default SG se adopta de una
# VPC real. Nada de lo que crean es infraestructura persistente.

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

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.referenced_security_group_id == aws_security_group.alb.id
    error_message = "El SG de app debe referenciar el SG del ALB."
  }

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

  # El único 0.0.0.0/0 de entrada legítimo está en el balanceador.
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
