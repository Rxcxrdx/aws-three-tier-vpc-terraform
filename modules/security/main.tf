# =============================================================================
#  Security groups encadenados: alb → app → db
#
#  La idea central es que ninguna regla entre capas menciona una dirección
#  IP. Cada capa autoriza al SECURITY GROUP de la capa anterior, no a su
#  rango de red. La diferencia importa: un CIDR autoriza a cualquier cosa
#  que aterrice en esa subred, mientras que una referencia a un security
#  group autoriza solo a las instancias que lo tengan puesto. Además
#  sobrevive intacta a cualquier renumeración de la red.
#
#  Se usan reglas como recurso propio (aws_vpc_security_group_ingress_rule)
#  en vez de bloques ingress/egress dentro del security group porque cada
#  regla tiene entonces su propia entrada en el state: añadir una no
#  reescribe las demás, y el plan muestra exactamente cuál cambia.
# =============================================================================

# --- Balanceador: la única capa expuesta a internet ---
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  vpc_id      = var.vpc_id
  description = "Recibe trafico HTTP/HTTPS desde internet"

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP desde internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS desde internet"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Salida libre hacia la capa de aplicacion"
}


# --- Aplicación: solo acepta lo que venga del balanceador ---
resource "aws_security_group" "app" {
  name_prefix = "${var.name}-app-"
  vpc_id      = var.vpc_id
  description = "Recibe trafico unicamente desde el ALB"

  tags = merge(var.tags, { Name = "${var.name}-app" })
}

# Sin cidr_ipv4: el origen es el security group del balanceador. Un test
# comprueba que siga siendo así, porque sustituir esto por un CIDR de
# subred es el atajo habitual cuando algo no conecta y no da error.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  description                  = "Solo desde el ALB"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Salida hacia la base de datos y servicios externos"
}


# --- Base de datos: solo acepta lo que venga de la aplicación ---
resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  vpc_id      = var.vpc_id
  description = "Recibe trafico unicamente desde la capa app"

  tags = merge(var.tags, { Name = "${var.name}-db" })
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  description                  = "Solo desde la capa de aplicacion"
}

# La base de datos no lleva regla de salida, y es deliberado: no tiene a
# dónde ir. Al no declarar ninguna, Terraform también elimina la regla de
# salida abierta que AWS añade por defecto a todo security group nuevo.
